defmodule Pipeline.State do
  @moduledoc """
  Simple state management
  """
  defstruct [:type, :initial_value, :value, :valid?, :errors]

  @type t :: %__MODULE__{
          type: atom(),
          initial_value: any(),
          value: any(),
          valid?: boolean(),
          errors: [any()]
        }

  @type result :: {:ok, any()} | {:error, any()}

  @typedoc """
  A reducer is an anonymous function or a tuple with module and function name.
  """
  @type reducer :: (any(), any() -> result()) | {atom(), atom()}

  @typedoc """
  A callback receives the a `State.t()` struct, some options. Any return is ignored.
  """
  @type callback :: (t(), any() -> any())

  alias Pipeline.TransformError

  @doc """
  Creates a new, valid, `%State{}` struct with the given initial value
  """
  @spec new(atom(), any()) :: t()
  def new(type, initial_value) do
    %__MODULE__{
      type: type,
      initial_value: initial_value,
      value: initial_value,
      valid?: true,
      errors: []
    }
  end

  @doc """
  Updates a state with the given anonymous function
  """
  @spec update(t(), reducer(), any()) :: t()
  def update(state, transform, options \\ nil)

  def update(%__MODULE__{valid?: true, value: value} = state, {module, fun}, options) do
    module
    |> apply(fun, [value, options])
    |> check_update(state)
  end

  def update(%__MODULE__{valid?: true, value: value} = state, transform, options)
      when is_function(transform, 2) do
    transform
    |> apply([value, options])
    |> check_update(state)
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
  Marks the given state as invalid and adds an error
  """
  @spec invalidate(t(), any) :: t()
  def invalidate(%__MODULE__{errors: errors} = state, error) do
    %__MODULE__{state | valid?: false, errors: [error | errors]}
  end
end
