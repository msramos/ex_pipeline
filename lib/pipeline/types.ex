defmodule Pipeline.Types do
  @moduledoc """
  Shared type definitions for all modules
  """

  @typedoc """
  The result of the execution of a step or the final result of an entire pipeline.
  """
  @type result :: {:ok, any} | {:error, any}

  @typedoc """
  The arguments that are used by the first step of a pipeline and well - the initial state of the pipeline.
  """
  @type args :: any

  @typedoc """
  The optional arguments that are passed to steps and callbacks of a pipeline.
  """
  @type options :: Keyword.t()

  @typedoc """
  A function that transforms a value into something else.
  """
  @type reducer :: (args(), options() -> result())

  @typedoc """
  A function that is always called after the pipeline finishes the execution.
  """
  @type hook :: (Pipeline.State.t(), options -> any())

  @typedoc """
  A function that is always called after the pipeline finishes the execution, but asynchronously.
  """
  @type async_hook :: hook()
end
