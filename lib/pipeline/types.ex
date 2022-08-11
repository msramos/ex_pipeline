defmodule Pipeline.Types do
  @moduledoc """
  Shared type definitions for all modules
  """

  @typedoc """
  A reference to a step/hook.

  It's a two-element tuple, where the first element is the module name and the second element is the function name.
  """
  @type step_ref :: {module(), atom()}

  @typedoc """
  The result of the execution of a step or the final result of an entire pipeline.
  """
  @type result :: {:ok, any()} | {:error, any()}

  @typedoc """
  The arguments that are used by the first step of a pipeline and well - the initial state of the pipeline.
  """
  @type args :: any()

  @typedoc """
  The optional arguments that are passed to steps and callbacks of a pipeline.
  """
  @type options :: Keyword.t()
end
