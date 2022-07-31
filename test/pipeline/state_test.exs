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
    end
  end

  describe "update/3 - anonymous functions" do
    test "updates an state succesfuly" do
      sum = fn value, options ->
        {:ok, value + options}
      end

      state = %State{valid?: true, value: 10, initial_value: 0, errors: []}

      updated_state = State.update(state, sum, 2)

      assert updated_state.errors == []
      assert updated_state.value == 12
      assert updated_state.initial_value == 0
      assert updated_state.valid? == true
    end

    test "raises an error if transform does not return a valid tuple" do
      transform = fn _state, _options ->
        123
      end

      state = %State{valid?: true, value: 10, initial_value: 0, errors: []}

      assert_raise TransformError,
                   "expected an ok or error tuple, got 123",
                   fn ->
                     State.update(state, transform, 2)
                   end
    end
  end

  describe "update/3 - modules and functions" do
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
      state = %State{valid?: true, value: 10, initial_value: 0, errors: []}

      updated_state = State.update(state, {__MODULE__.Example1, :good}, 2)

      assert updated_state.errors == []
      assert updated_state.value == [10, 2]
      assert updated_state.initial_value == 0
      assert updated_state.valid? == true
    end

    test "invalidates the state if step returns an error tuple" do
      state = %State{valid?: true, value: 10, initial_value: 0, errors: []}

      updated_state = State.update(state, {__MODULE__.Example1, :error_message}, 2)

      assert updated_state.errors == ["Something is not good"]
      assert updated_state.value == 10
      assert updated_state.initial_value == 0
      assert updated_state.valid? == false
    end

    test "invalidates the state if step returns an :error atom" do
      state = %State{valid?: true, value: 10, initial_value: 0, errors: []}

      updated_state = State.update(state, {__MODULE__.Example1, :error}, 2)

      assert updated_state.errors == []
      assert updated_state.value == 10
      assert updated_state.initial_value == 0
      assert updated_state.valid? == false
    end

    test "does not perform any action if the state is invalid" do
      state = %State{valid?: false, value: 10, initial_value: 0, errors: ["Some error"]}

      updated_state = State.update(state, {__MODULE__.Example1, :good})

      assert updated_state == state
    end

    test "uses empty options by default" do
      state = %State{valid?: true, value: 10, initial_value: 0, errors: []}

      updated_state = State.update(state, {__MODULE__.Example1, :good})

      assert updated_state.errors == []
      assert updated_state.value == [10, []]
      assert updated_state.initial_value == 0
      assert updated_state.valid? == true
    end

    test "raises an error if transform does not return a tuple" do
      state = %State{valid?: true, value: 10, initial_value: 0, errors: []}

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

  describe "callback/3 - anonymous functions" do
    test "calls a callback from anonymous function succesfully" do
      callback = fn state, options ->
        send(self(), {:state, state, options})
      end

      state = %State{valid?: true, value: 10, initial_value: 0, errors: []}
      options = [opt: 123]

      State.callback(state, callback, options)

      assert_received {:state, ^state, [opt: 123]}
    end
  end
end
