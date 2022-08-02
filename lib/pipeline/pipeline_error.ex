defmodule Pipeline.PipelineError do
  @moduledoc """
  Error thrown when buidling a pipeline with invalid steps or callbacks.

  This error is thrown at compile time when, inside a module that requires the `Pipeline` using `use Pipeline`, a
  function is declared if the suffic `_step` or `_callback` but do not accept two parameters.
  """
  defexception [:message]
end
