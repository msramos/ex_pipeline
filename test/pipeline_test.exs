defmodule PipelineTest do
  use ExUnit.Case
  doctest Pipeline

  defmodule GoodPipeline do
    use Pipeline

    def first_step(value, options) do
      send(self(), {:first, value, options})
      {:ok, value + 1}
    end

    def second_step(value, options) do
      send(self(), {:second, value, options})
      {:ok, value + 1}
    end

    def single_callback(state, options) do
      send(self(), {:callback, state, options})
    end
  end

  defmodule PipelineWithError do
    use Pipeline

    def first_step(value, options) do
      send(self(), {:first, value, options})
      {:error, "Some error"}
    end

    def second_step(value, options) do
      send(self(), {:second, value, options})
      {:ok, value + 1}
    end

    def single_callback(state, options) do
      send(self(), {:callback, state, options})
    end
  end

  defmodule BadPipeline do
  end

  describe "execute/3" do
    test "executes all steps and callbacks in a module" do
      result = Pipeline.execute(__MODULE__.GoodPipeline, 0, opt: true)
      assert result == {:ok, 2}
      assert_received {:first, 0, opt: true}
      assert_received {:second, 1, opt: true}

      assert_received {:callback,
                       %Pipeline.State{valid?: true, initial_value: 0, value: 2, errors: []},
                       [opt: true]}
    end

    test "do not execute steps after a failure, but still call callbacks anyways" do
      result = Pipeline.execute(__MODULE__.PipelineWithError, 0)
      assert result == {:error, ["Some error"]}
      assert_received {:first, 0, []}
      refute_received {:second, 1, []}

      assert_received {:callback,
                       %Pipeline.State{
                         valid?: false,
                         initial_value: 0,
                         value: 0,
                         errors: ["Some error"]
                       }, []}
    end

    test "fails if pipeline is invalid" do
      assert_raise Pipeline.PipelineError, fn ->
        Pipeline.execute(__MODULE__.BadPipeline, 10)
      end
    end
  end
end
