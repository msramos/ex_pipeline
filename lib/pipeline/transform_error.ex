defmodule Pipeline.TransformError do
  @moduledoc """
  Error thrown at runtime when steps return invalid values.

  This error is thrown if a step returns a value that is not an ok/error tuple, as defined by `Pipeline.Types.result()`
  typespec.
  """
  defexception [:message]
end
