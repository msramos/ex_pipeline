defmodule Pipeline.State do
  @moduledoc """
  Pipeline state management.

  This module defines a struct that is used to keep track of the state of a pipeline: the initial value, the current
  value, it's still valid (or not) and any error that may have occurred.

  It also has functions to create and manipulate a state.

  You probably won't need to interact with this module too often, since it's all managed by the pipeline engine. The
  only part of a pipeline where this module is accessible is on callback functions.
  """
  defstruct [:initial_value, :value, :valid?, :error, :executed_steps]

  @typedoc """
  A struct that wraps metadata information about a pipeline.

  * `initial_value` is the first ever value that is passed to the first step on a pipeline.
  * `value` is the current value of the pipeline
  * `valid?` is boolean indicating wether the pipeline is still valid (true) or not (false).
  * `error` the error that may have happened during the execution of the pipeline.
  * `executed_steps` a list of all steps that were executed
  """
  @type t :: %__MODULE__{
          initial_value: any(),
          value: any(),
          valid?: boolean(),
          error: any(),
          executed_steps: [{module, atom}]
        }

  alias Pipeline.TransformError
  alias Pipeline.Types

  @doc """
  Creates a new, valid, `%Pipeline.State{}` struct with the given initial value

  ## Examples

      iex> Pipeline.State.new(%{id: 1})
      %Pipeline.State{error: nil, executed_steps: [], initial_value: %{id: 1}, valid?: true, value: %{id: 1}}
  """
  @spec new(any()) :: t()
  def new(initial_value) do
    %__MODULE__{
      initial_value: initial_value,
      value: initial_value,
      valid?: true,
      error: nil,
      executed_steps: []
    }
  end

  @doc """
  Updates a state with the given reducer.

  If everything goes well and the function returns an ok tuple, it will return an updated `%Pipeline.State{}` struct.

  If the function returns an error tuple, it will call `invalidate/1` or `invalidate/2` and return an updated and
  invalid `%Pipeline.State{}` struct.

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
  Marks the given state as invalid.

  Since no errors are specified, the `error` field on the state becomes a generic error string.

  ## Examples

      iex> %Pipeline.State{valid?: true, error: nil} |> Pipeline.State.invalidate()
      %Pipeline.State{error: "an error occured during the execution of the pipeline", valid?: false}
  """
  @spec invalidate(t()) :: t()
  def invalidate(%__MODULE__{} = state) do
    %__MODULE__{
      state
      | valid?: false,
        error: "an error occured during the execution of the pipeline"
    }
  end

  @doc """
  Marks the given state as invalid and adds an error to the state.

  The `error` field on the state will have the same value from the given error.

  ## Examples

      iex> %Pipeline.State{valid?: true, error: nil} |> Pipeline.State.invalidate(:bad_thing)
      %Pipeline.State{error: :bad_thing, valid?: false}
  """
  @spec invalidate(t(), any()) :: t()
  def invalidate(%__MODULE__{} = state, error) do
    %__MODULE__{state | valid?: false, error: error}
  end
end
