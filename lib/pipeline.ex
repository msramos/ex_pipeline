defmodule Pipeline do
  @moduledoc """
  Pipeline management.
  """
  alias Pipeline.PipelineError
  alias Pipeline.State

  @type result :: {:ok, any} | {:error, any}
  @type args :: any
  @type options :: Keyword.t()
  @type reducer :: (args, options -> result)
  @type callback :: (State.t(), options -> any())

  @doc """
  Returns a list of functions to be used as steps of a pipeline. These steps will be executed in the same order that
  they appear on this list.
  """
  @callback __pipeline_steps__() :: [reducer]

  @doc """
  Returns a list of functions to be used as callbacks of a pipeline. These callbacks will be executed in the same order
  that they appear on this list.
  """
  @callback __pipeline_callbacks__() :: [callback]

  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end

  # Injects the Pipeline behaviour, the two required callbacks and an `execute/2` function
  defmacro __before_compile__(env) do
    definitions = Module.definitions_in(env.module, :def)
    steps = filter_functions(env.module, definitions, "_step", 2)
    callbacks = filter_functions(env.module, definitions, "_callback", 2)

    quote do
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def __pipeline_steps__, do: unquote(steps)

      @impl unquote(__MODULE__)
      def __pipeline_callbacks__, do: unquote(callbacks)

      def execute(value, options \\ []) do
        apply(unquote(__MODULE__), :execute, [__MODULE__, value, options])
      end
    end
  end

  defp filter_functions(module, definitions, suffix, expected_arity) do
    functions =
      Enum.reduce(definitions, [], fn {function, arity}, acc ->
        valid_name? =
          function
          |> Atom.to_string()
          |> String.ends_with?(suffix)

        has_expected_args? = arity == expected_arity

        cond do
          valid_name? and has_expected_args? ->
            {_, _, [line: line], _} = Module.get_definition(module, {function, arity})
            [{module, function, line} | acc]

          valid_name? ->
            raise(
              PipelineError,
              "Function #{function} does not accept #{expected_arity} parameters."
            )

          true ->
            acc
        end
      end)

    functions
    # order by line number
    |> Enum.sort(fn {_, _, a}, {_, _, b} -> a <= b end)
    # drop line number
    |> Enum.map(fn {m, f, _l} -> {m, f} end)
  end

  @doc """
  Executes the pipeline defined by `module` with the given `value` and `options`.
  """
  def execute(module, value, options \\ []) do
    ensure_valid_pipeline!(module)

    initial_state = State.new(value)
    steps = apply(module, :__pipeline_steps__, [])
    callbacks = apply(module, :__pipeline_callbacks__, [])

    final_state =
      Enum.reduce(steps, initial_state, fn reducer, curent_state ->
        State.update(curent_state, reducer, options)
      end)

    Enum.each(callbacks, fn callback ->
      State.callback(final_state, callback, options)
    end)

    case final_state do
      %State{valid?: true, value: value} ->
        {:ok, value}

      %State{errors: errors} ->
        {:error, errors}
    end
  end

  defp ensure_valid_pipeline!(module) do
    exports_steps? = function_exported?(module, :__pipeline_steps__, 0)
    exports_callbacks? = function_exported?(module, :__pipeline_callbacks__, 0)

    unless exports_steps? && exports_callbacks? do
      raise(PipelineError, "Module #{module} is not a valid pipeline.")
    end
  end
end
