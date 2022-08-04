defmodule Pipeline.StateTest do
  use ExUnit.Case

  alias Pipeline.State
  alias Pipeline.TransformError

  doctest State

  describe "new/2" do
    test "creates a valid state with initial and current value" do
      state = State.new([1, 2, 3])

      assert state.initial_value == [1, 2, 3]
      assert state.value == [1, 2, 3]
      assert state.errors == []
      assert state.valid? == true
      assert state.executed_steps == []
    end
  end

  describe "update/3" do
    defmodule __MODULE__.Example1 do
      def good(value, options) do
        {:ok, [value, options]}
      end

      def error_message(_value, _options) do
        {:error, "Something is not good"}
      end

      def error(_value, _options) do
        :error
      end

      def bad_return(value, _) do
        value
      end
    end

    test "updates an state succesfully" do
      state = %State{valid?: true, value: 10, initial_value: 0, errors: [], executed_steps: []}

      updated_state = State.update(state, {__MODULE__.Example1, :good}, 2)

      assert updated_state.errors == []
      assert updated_state.value == [10, 2]
      assert updated_state.initial_value == 0
      assert updated_state.valid? == true
      assert updated_state.executed_steps == [{__MODULE__.Example1, :good}]
    end

    test "invalidates the state if step returns an error tuple" do
      state = %State{valid?: true, value: 10, initial_value: 0, errors: [], executed_steps: []}

      updated_state = State.update(state, {__MODULE__.Example1, :error_message}, 2)

      assert updated_state.errors == ["Something is not good"]
      assert updated_state.value == 10
      assert updated_state.initial_value == 0
      assert updated_state.valid? == false
      assert updated_state.executed_steps == [{__MODULE__.Example1, :error_message}]
    end

    test "invalidates the state if step returns an :error atom" do
      state = %State{valid?: true, value: 10, initial_value: 0, errors: [], executed_steps: []}

      updated_state = State.update(state, {__MODULE__.Example1, :error}, 2)

      assert updated_state.errors == []
      assert updated_state.value == 10
      assert updated_state.initial_value == 0
      assert updated_state.valid? == false
      assert updated_state.executed_steps == [{__MODULE__.Example1, :error}]
    end

    test "does not perform any action if the state is invalid" do
      state = %State{
        valid?: false,
        value: 10,
        initial_value: 0,
        errors: ["Some error"],
        executed_steps: []
      }

      updated_state = State.update(state, {__MODULE__.Example1, :good})

      assert updated_state == state
      assert updated_state.executed_steps == []
    end

    test "uses empty options by default" do
      state = %State{valid?: true, value: 10, initial_value: 0, errors: [], executed_steps: []}

      updated_state = State.update(state, {__MODULE__.Example1, :good})

      assert updated_state.errors == []
      assert updated_state.value == [10, []]
      assert updated_state.initial_value == 0
      assert updated_state.valid? == true
      assert updated_state.executed_steps == [{__MODULE__.Example1, :good}]
    end

    test "raises an error if transform does not return a tuple" do
      state = %State{valid?: true, value: 10, initial_value: 0, errors: [], executed_steps: []}

      assert_raise TransformError,
                   "expected an ok or error tuple, got 10",
                   fn ->
                     State.update(state, {__MODULE__.Example1, :bad_return}, 2)
                   end
    end
  end

  describe "callback/3 - modules and functions" do
    defmodule __MODULE__.Example2 do
      def callback(state, options) do
        send(self(), {:state, state, options})
      end
    end

    test "calls a callback function succesfully" do
      state = %State{valid?: true, value: 10, initial_value: 0, errors: []}
      options = [opt: 123]

      State.callback(state, {__MODULE__.Example2, :callback}, options)

      assert_received {:state, ^state, [opt: 123]}
    end
  end
end
