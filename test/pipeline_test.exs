defmodule PipelineTest do
  use ExUnit.Case, async: true
  doctest Pipeline

  defmodule GoodPipeline do
    use Pipeline

    def first_step(value, _options) do
      send(self(), {:first, value})
      {:ok, value + 1}
    end

    def some_function, do: :ok

    def second_step(value, _options) do
      send(self(), {:second, value})
      {:ok, value + 1}
    end

    def another_function, do: :ok

    def single_hook(state, _options) do
      send(self(), {:hook, state})
    end

    def error_handler(_state, _options) do
      send(self(), :error)
      :error
    end

    def single_async_hook(state, options) do
      send(options[:parent_pid], {:async_hook, state})
    end
  end

  defmodule PipelineWithError do
    use Pipeline

    def first_step(value, _options) do
      send(self(), {:first, value})
      {:error, "Some error"}
    end

    def second_step(value, _options) do
      send(self(), {:second, value})
      {:ok, value + 1}
    end

    def single_hook(state, _options) do
      send(self(), {:hook, state})
    end

    def error_handler(%Pipeline.State{error: error}, _options) do
      send(self(), {:handler, error})
      error
    end

    def single_async_hook(state, options) do
      send(options[:parent_pid], {:async_hook, state})
    end
  end

  defmodule BadPipeline do
  end

  describe "code injection" do
    test "target module has the __pipeline__/0 and execute/2 functions injected" do
      assert function_exported?(__MODULE__.GoodPipeline, :__pipeline__, 0)
      assert function_exported?(__MODULE__.GoodPipeline, :execute, 2)
    end

    test "the injected __pipeline__ returns only the matched functions for steps, handlers, hooks and async hooks" do
      {steps, hooks, async_hooks, handlers} = __MODULE__.GoodPipeline.__pipeline__()

      assert steps == [
               {__MODULE__.GoodPipeline, :first_step},
               {__MODULE__.GoodPipeline, :second_step}
             ]

      assert hooks == [
               {__MODULE__.GoodPipeline, :single_hook}
             ]

      assert async_hooks == [
               {__MODULE__.GoodPipeline, :single_async_hook}
             ]

      assert handlers == [
               {__MODULE__.GoodPipeline, :error_handler}
             ]
    end
  end

  describe "execute/3" do
    test "executes all steps and hooks in a module" do
      result = Pipeline.execute(__MODULE__.GoodPipeline, 10, parent_pid: self())
      assert result == {:ok, 12}
      assert_receive {:first, 10}
      assert_receive {:second, 11}
      refute_receive {:handler, :error}

      assert_receive {:hook,
                      %Pipeline.State{valid?: true, initial_value: 10, value: 12, error: nil}}

      assert_receive {:async_hook,
                      %Pipeline.State{valid?: true, initial_value: 10, value: 12, error: nil}}
    end

    test "do not execute steps after a failure, but still call handlers and hooks anyways" do
      result = Pipeline.execute(__MODULE__.PipelineWithError, 0, parent_pid: self())
      assert result == {:error, "Some error"}

      assert_receive {:first, 0}
      refute_receive {:second, 1}

      assert_receive {:handler, "Some error"}

      assert_receive {:hook,
                      %Pipeline.State{
                        valid?: false,
                        initial_value: 0,
                        value: 0,
                        error: "Some error"
                      }}

      assert_receive {:async_hook,
                      %Pipeline.State{
                        valid?: false,
                        initial_value: 0,
                        value: 0,
                        error: "Some error"
                      }}
    end

    test "fails if pipeline is invalid" do
      assert_raise Pipeline.PipelineError, fn ->
        Pipeline.execute(__MODULE__.BadPipeline, 10)
      end
    end
  end
end
