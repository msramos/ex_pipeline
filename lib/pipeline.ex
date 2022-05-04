defmodule Pipeline do
  @moduledoc """
  A pipeline of changes
  """
  defstruct [:state, :init, :reducers, :callbacks]

  alias Pipeline.State

  @type t :: %__MODULE__{
          state: State.t(),
          reducers: [State.reducer()],
          callbacks: [State.callback()]
        }

  @doc false
  defmacro __using__(_) do
    quote do
      import Pipeline
      require Pipeline

      Module.register_attribute(__MODULE__, :pipeline_type, accumulate: false)
      Module.register_attribute(__MODULE__, :pipeline_init, accumulate: false)
      Module.register_attribute(__MODULE__, :pipeline_reducers, accumulate: true)
      Module.register_attribute(__MODULE__, :pipeline_callbacks, accumulate: true)
    end
  end

  @doc """
  Defines a pipeline within a module
  """
  defmacro pipeline(type, do: block) do
    quote do
      unquote(block)

      @pipeline_type unquote(type)

      def __execute_pipeline__(args, options) do
        Pipeline.__execute__(
          __MODULE__,
          @pipeline_type,
          @pipeline_init,
          Enum.reverse(@pipeline_reducers),
          Enum.reverse(@pipeline_callbacks),
          args,
          options
        )
      end
    end
  end

  @doc """
  Defines the init function of a module-base pipeline.

  The function must accept one parameter and return an `%Pipeline.State{}` struct.

  If an init function is not provided, a new state will be generated using the function `__new_state__/2`, and the
  type is inferred from the `pipeline/2` macro.

  ## Example

      defmodule MyPipeline do
        use Pipeline
        pipeline :insert_user do
          init :from_params
        end

        def from_params(value), do: Pipeline.State.new(:my_type, value)
      end

  """
  defmacro init(function) do
    quote do
      @pipeline_init unquote(function)
    end
  end

  @doc """
  Registers a function on the caller module to be a reducer of a pipeline.

  The function **MUST** exist within the caller module, and return an ok or error tuple.


  ## Example

      defmodule MyPipeline do
        use Pipeline
        pipeline :numbers do
          step :double
          step :half
        end

        def double(number, _), do: number * 2
        def half(number, _), do: number /2
      end
  """
  defmacro step(f) do
    quote do
      @pipeline_reducers {__MODULE__, unquote(f)}
    end
  end

  @doc """
  Registers a function on the caller module to be a callback of a pipeline.

  The function **MUST** exist within the caller module, and **MUST** have arity 2:

  - The first parameter is a `%Pipeline.State{}` struct
  - The second parameter is the options and can have any value

  ## Example

      defmodule MyPipeline do
        use Pipeline
        pipeline :numbers do
          then :print
        end

        def print(%Pipeline.State{value: value}, _), do: IO.inspect(value, label: "Result")
      end
  """
  defmacro then(f) do
    quote do
      @pipeline_callbacks {__MODULE__, unquote(f)}
    end
  end

  @doc false
  def __execute__(module, type, init_function, reducers, callbacks, args, options) do
    p = __pipeline__(module, type, init_function, reducers, callbacks, args)
    execute(p, options)
  end

  @doc false
  def __pipeline__(module, type, init_function, reducers, callbacks, args) do
    state =
      if init_function == nil do
        __new_state__(type, args)
      else
        apply(module, init_function, [args])
      end

    Pipeline.new(state, reducers, callbacks)
  end

  @doc false
  def __new_state__(type, args), do: Pipeline.State.new(type, args)

  @doc """
  Creates a new pipeline with the given state, reducers and callbacks
  """
  @spec new(State.t(), [State.reducer()], [State.callback()]) :: t()
  def new(%State{} = state, reducers \\ [], callbacks \\ []) do
    %__MODULE__{state: state, reducers: reducers, callbacks: callbacks}
  end

  @doc """
  Add a reducer to the given pipeline.
  """
  @spec reduce(t(), State.reducer()) :: State.Pipeline.t()
  def reduce(%__MODULE__{} = pipeline, reducer) do
    %__MODULE__{pipeline | reducers: pipeline.reducers ++ [reducer]}
  end

  @doc """
  Add a callback to the given pipeline
  """
  @spec callback(t(), State.callback()) :: State.Pipeline.t()
  def callback(%__MODULE__{} = pipeline, callback) do
    %__MODULE__{pipeline | reducers: [callback | pipeline.callbacks]}
  end

  @doc """
  Executes the given pipeline.

  A pipeline can be one of:
  - `Pipeline.t()` struct
  - A module that uses the `pipeline/2` macro
  """
  @spec execute(State.Pipeline.t(), any) :: State.result()
  def execute(struct_or_mod, args \\ nil, options \\ nil)

  def execute(
        %__MODULE__{state: state, reducers: reducers, callbacks: callbacks},
        options,
        _ignored
      ) do
    desired_state =
      Enum.reduce(reducers, state, fn reducer, current_state ->
        State.update(current_state, reducer, options)
      end)

    Enum.each(callbacks, fn callback ->
      State.callback(desired_state, callback, options)
    end)

    case desired_state do
      %State{valid?: true, value: value} ->
        {:ok, value}

      %State{errors: errors} ->
        {:error, errors}
    end
  end

  def execute(module, args, options) when is_atom(module) do
    if function_exported?(module, :__execute_pipeline__, 2) do
      apply(module, :__execute_pipeline__, [args, options])
    else
      raise "Module #{module} is not a valid pipeline."
    end
  end
end
