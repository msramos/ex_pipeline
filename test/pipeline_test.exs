defmodule PipelineTest do
  use ExUnit.Case

  defmodule Example do
    use Pipeline

    require Logger

    pipeline :type do
      init(:state_from_number)

      step(:double)
      step(:triple)

      then(:print)
    end

    def state_from_number(number), do: Pipeline.State.new(:number, number)
    def double(value, _options), do: {:ok, value * 2}
    def triple(value, _options), do: {:ok, value * 3}
    def print(%Pipeline.State{value: value}, _options), do: send(self(), value)
  end

  describe "execute/3" do
    test "executes a pipeline from a struct" do
      state = Pipeline.State.new(:test, 0)

      result =
        state
        |> Pipeline.new()
        |> Pipeline.reduce(fn v, _ -> {:ok, v + 1} end)
        |> Pipeline.reduce(fn v, _ -> {:ok, v + 2} end)
        |> Pipeline.execute()

      assert result == {:ok, 3}
    end

    test "executes a module-based pipeline" do
      result = Pipeline.execute(__MODULE__.Example, 10, 30)

      assert result == {:ok, 60}
      assert_received 60
    end
  end
end
