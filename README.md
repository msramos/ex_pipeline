![CI](https://github.com/msramos/ex_pipeline/actions/workflows/ci.yml/badge.svg)

# ExPipeline

An opinionated library to build better pipelines.

## Creating a Pipeline

On the module that will implement the pipeline, simplye `use Pipeline` and you are ready to go.

- A function is considered a step if its name ends with `_step` and accepts exactly two parameters
- A function is considered a callback if its name ends with `_callback` and accepts exactly two parameters
- Steps and callbacks are executed in the order they are declared
- Steps must always return an ok/error tuple: `{:ok, value}` or `{:error, error}`
- If one step fails, following steps will not be executed
- Callbacks are always executed after all steps are called, regardless of the final result.

An example:
```elixir
defmodule MyModule do
  use Pipeline

  @doc """
  First step of the pipeline
  """
  def init_step(value, options) do
    # {:ok, updated_value}
    # or
    # {:error, some_error}
  end

  @doc """
  Second step of the pipeline
  """
  def second_step(value, options) do
    # {:ok, updated_value}
    # or
    # {:error, some_error}
  end

  @doc """
  Callback - always executed, results ignored
  """
  def report_callback(state, _options) do
    MyReportingModule.publish(state)
  end
end
```

With this module in place, you have two options to execute it:
- Calling the `execute/2` function from your module
- Calling the `execute/3` function from the `Pipeline` module

Both lines will execute the pipeline:
```elixir
MyModule.execute(starting_value, options)
Pipeline.execute(MyModule, starting_value, options)
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_pipeline` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_pipeline, "~> 0.1.0"}
  ]
end
```
