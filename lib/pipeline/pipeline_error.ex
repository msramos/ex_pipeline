defmodule Pipeline.PipelineError do
  @moduledoc """
  Error thrown when building a pipeline with invalid steps or hooks.

  This error is thrown at compile time when, inside a module that requires the `Pipeline` using `use Pipeline`, a
  function is declared if the suffix `_step`, `_hook` or `_async_hook` but do not accept two parameters.
  """
  defexception [:message]
end
