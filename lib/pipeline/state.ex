defmodule Pipeline.State do
  @moduledoc """
  Pipeline state management.

  This module defines a struct that is used to keep track of the state of a pipeline: the initial value, the current
  value, it's still valid (or not) and any error that may have occurred.

  It also has functions to create and manipulate a state.

  You probably won't need to interact with this module too often, since it's all managed by the pipeline engine. The
  only part of a pipeline where this module is accessible is on callback functions.
  """
  defstruct [:initial_value, :value, :valid?, :errors, :executed_steps]

  @typedoc """
  A struct that wraps metadata information about a pipeline.

  * `initial_value` is the first ever value that is passed to the first step on a pipeline.
  * `value` is the current value of the pipeline
  * `valid?` is boolean indicating wether the pipeline is still valid (true) or not (false).
  * `errors` is a list of all errors that may have happened during the execution of the pipeline.
  * `executed_steps` a list of all steps that were executed
  """
  @type t :: %__MODULE__{
          initial_value: any(),
          value: any(),
          valid?: boolean(),
          errors: [any()],
          executed_steps: [{module, atom}]
        }

  alias Pipeline.TransformError
  alias Pipeline.Types

  @doc """
  Creates a new, valid, `%State{}` struct with the given initial value
  """
  @spec new(any()) :: t()
  def new(initial_value) do
    %__MODULE__{
      initial_value: initial_value,
      value: initial_value,
      valid?: true,
      errors: [],
      executed_steps: []
    }
  end

  @doc """
  Updates a state with the given function.

  If everything goes well and the function returns an ok tuple, it will return an updated `%__MODULE__{}` struct.

  If the function returns an error tuple, it will call `invalidate/1` or `invalidate/2` and return an updated and
  invalid `%__MODULE__{}` struct.

  Note that the function must return an ok/error tuple, otherwise a `Transform.Error` error is thrown.
  """
  @spec update(t(), Types.reducer(), Types.options()) :: t()
  def update(state, transform, options \\ [])

  def update(%__MODULE__{valid?: true, value: value} = state, {module, fun} = reducer, options) do
    updated_state =
      module
      |> apply(fun, [value, options])
      |> check_update(state)

    %__MODULE__{updated_state | executed_steps: state.executed_steps ++ [reducer]}
  end

  def update(%__MODULE__{valid?: false} = state, _transform, _options), do: state

  # Check if the transformation is valid
  defp check_update(new_value, state) do
    case new_value do
      {:ok, value} ->
        %__MODULE__{state | value: value}

      {:error, error} ->
        invalidate(state, error)

      :error ->
        invalidate(state)

      unexpected ->
        raise(TransformError, "expected an ok or error tuple, got #{inspect(unexpected)}")
    end
  end

  @doc """
  Executes the given callback passing the `state` and `options` as parameters.
  """
  @spec callback(t(), Types.reducer(), Types.options()) :: any()
  def callback(state, fun, options)

  def callback(state, {mod, fun}, options) do
    apply(mod, fun, [state, options])
  end

  def callback(state, fun, options) when is_function(fun, 2) do
    apply(fun, [state, options])
  end

  @doc """
  Marks the given state as invalid
  """
  @spec invalidate(t()) :: t()
  def invalidate(%__MODULE__{} = state) do
    %__MODULE__{state | valid?: false}
  end

  @doc """
  Marks the given state as invalid and adds an error to the state.
  """
  @spec invalidate(t(), any) :: t()
  def invalidate(%__MODULE__{errors: errors} = state, error) do
    %__MODULE__{state | valid?: false, errors: [error | errors]}
  end
end
