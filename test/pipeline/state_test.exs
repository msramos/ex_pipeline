defmodule Pipeline.StateTest do
  use ExUnit.Case

  alias Pipeline.State
  alias Pipeline.TransformError

  doctest State

  describe "new/2" do
    test "creates a valid state with initial and current value" do
      state = State.new(:some_type, [1, 2, 3])

      assert state.type == :some_type
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

      state = %State{type: :test, valid?: true, value: 10, initial_value: 0, errors: []}

      updated_state = State.update(state, sum, 2)

      assert updated_state.type == :test
      assert updated_state.errors == []
      assert updated_state.value == 12
      assert updated_state.initial_value == 0
      assert updated_state.valid? == true
    end

    test "raises an error if transform does not return a valid tuple" do
      transform = fn _state, _options ->
        123
      end

      state = %State{type: :test, valid?: true, value: 10, initial_value: 0, errors: []}

      assert_raise TransformError,
                   "expected an ok or error tuple, got 123",
                   fn ->
                     State.update(state, transform, 2)
                   end
    end
  end

  describe "update/3 - modules and functions" do
    defmodule __MODULE__.Example do
      def good(value, options) do
        {:ok, value + options}
      end

      def bad_return(value, _) do
        value
      end
    end

    test "updates an state succesfully" do
      state = %State{type: :test, valid?: true, value: 10, initial_value: 0, errors: []}

      updated_state = State.update(state, {__MODULE__.Example, :good}, 2)

      assert updated_state.type == :test
      assert updated_state.errors == []
      assert updated_state.value == 12
      assert updated_state.initial_value == 0
      assert updated_state.valid? == true
    end

    test "raises an error if transform does not return a tuple" do
      state = %State{type: :test, valid?: true, value: 10, initial_value: 0, errors: []}

      assert_raise TransformError,
                   "expected an ok or error tuple, got 10",
                   fn ->
                     State.update(state, {__MODULE__.Example, :bad_return}, 2)
                   end
    end
  end
end
