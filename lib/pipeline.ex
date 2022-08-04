defmodule Pipeline do
  @moduledoc """
  Pipeline definition and execution.

  ## What is a "pipeline"?

  A pipeline is set of functions that must be executed in a specific order to transform an initial state into a desired
  state. For example, a "login pipeline" uses the request body as its initial state and generates an authentication
  token.

  ## Creating a pipeline

  To create a new feature as a pipeline, you can simply `use Pipeline` in the target module and start writing
  functions: steps and callbacks.

  ### Pipeline Steps

  - Steps are executed in the same order that they are declared in the module.
  - Any function that ends with `_step` and accepts two parameters is considered a step in the pipeline.
  - A step accepts a value and must return an ok tuple with the updated value or an error tuple with the error
   description. If one step failes, the following steps are not executed.
    - The first parameter is the value that's being transformed by each step
    - The second parameter are optional values and it's immutable

  ### Pipeline Callbacks

  - Callbacks are executed in the same order that they are declared in the module.
  - Any function that ends with  `_callback` and accepts two parameters is considered a callback in the pipeline.
  - Callbacks receive the final state of the pipeline, and they are always executed after all steps.
    - The first parameter is the final state as defined by the `%Pipeline.State{}` struct.
    - The second parameter are optional values and it's immutable, the same used by the steps.

  ## Example

  ```elixir
  defmodule StringToNumber do
    use Pipeline

    def detect_binary_step(value, _options) do
      cond do
        is_binary(value) ->
          {:ok, value}

        true ->
          {:error, "Not a string"}
      end
    end

    def cleanup_step(value, _options) do
      {:ok, String.trim(value)}
    end

    def parse_step(value, _options) do
      case Float.parse(value) do
        {number, _} ->
          {:ok, number}

        :error ->
          {:error, "Invalid number"}
      end
    end
  end
  ```

  To execute this pipeline, you can use `StringToNumber.execute/2` or `Pipeline.execute/3`

  """
  alias Pipeline.PipelineError
  alias Pipeline.State
  alias Pipeline.Types

  @doc """
  Returns a list of tuple with two elements.

  The first element is a list of functions to be used as steps of a pipeline. These steps will be executed in the same
  order that they appear on this list.

  The second element is a list of functions to be used as callbacks of a pipeline. These callbacks will be executed in
  the same order that they appear on this list.
  """
  @callback __pipeline__() :: {[Types.reducer()], [Types.callback()]}

  @doc false
  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end

  # "Injects the Pipeline behaviour, the two required callbacks and an `execute/2` function"
  @doc false
  defmacro __before_compile__(env) do
    definitions = Module.definitions_in(env.module, :def)
    steps = filter_functions(env.module, definitions, "_step", 2)
    callbacks = filter_functions(env.module, definitions, "_callback", 2)

    quote do
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def __pipeline__, do: {unquote(steps), unquote(callbacks)}

      @spec execute(Pipeline.Types.args(), Pipeline.Types.options()) :: Pipeline.Types.result()
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

  First, all steps are executed in the same order that they were declared on their module. If one step fails, all
  the steps that come after it will not be executed. The returned value from one step will be passed to the next step,
  along with the given `options`.

  After that, all callbacks are executed in the same order that they were declared on their module. They will
  receive the final `%Pipeline.State{}` along with the given `options`. Their return values are ignored.

  Once steps and callbacks are executed, the state is evaluated and then this function will returns an ok or error
  tuple, depending wether or not the state is valid.

  If the given `module` does not implement the required callbacks from `Pipeline` behaviour, a `PipelineError` will
  be thrown.
  """
  @spec execute(module(), Types.args(), Types.options()) :: Types.result()
  def execute(module, value, options \\ []) do
    ensure_valid_pipeline!(module)

    initial_state = State.new(value)
    {steps, callbacks} = apply(module, :__pipeline__, [])

    final_state =
      Enum.reduce(steps, initial_state, fn reducer, curent_state ->
        State.update(curent_state, reducer, options)
      end)

    Enum.each(callbacks, fn {mod, fun} ->
      apply(mod, fun, [final_state, options])
    end)

    case final_state do
      %State{valid?: true, value: value} ->
        {:ok, value}

      %State{error: error} ->
        {:error, error}
    end
  end

  defp ensure_valid_pipeline!(module) do
    exports_pipeline_meta? = function_exported?(module, :__pipeline__, 0)

    unless exports_pipeline_meta? do
      raise(PipelineError, "Module #{module} is not a valid pipeline.")
    end
  end
end
