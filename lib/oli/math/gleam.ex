defmodule Oli.Math.Gleam do
  @moduledoc false

  @gleam_erlang_build Path.expand("../../../gleam/build/dev/erlang", __DIR__)

  defmodule MissingFunctionError do
    defexception [:module, :function, :arity, :paths]

    @impl true
    def message(%{module: module, function: function, arity: arity, paths: paths}) do
      """
      Gleam function #{inspect(module)}.#{function}/#{arity} is unavailable.
      Run `cd gleam && gleam build --target erlang`, then restart or retry the dev server.
      Searched ebin paths: #{Enum.join(paths, ", ")}
      """
      |> String.trim()
    end
  end

  def call(module, function, args) do
    paths = ensure_gleam_code_path!()
    ensure_exported!(module, function, length(args), paths)
    apply(module, function, args)
  end

  defp ensure_gleam_code_path! do
    # The Mix project compiles Gleam and its Gleam package dependencies under
    # `gleam/build`. Add every generated ebin path here so wrappers can call the
    # public Gleam boundary without copying generated artifacts into Torus.
    @gleam_erlang_build
    |> Path.join("*/ebin")
    |> Path.wildcard()
    |> tap(fn paths -> Enum.each(paths, &add_code_path/1) end)
  end

  defp ensure_exported!(module, function, arity, paths) do
    :code.ensure_loaded(module)

    if function_exported?(module, function, arity) do
      :ok
    else
      reload_module(module)

      unless function_exported?(module, function, arity) do
        raise MissingFunctionError,
          module: module,
          function: function,
          arity: arity,
          paths: paths
      end
    end
  end

  defp reload_module(module) do
    :code.purge(module)
    :code.delete(module)
    :code.ensure_loaded(module)
  end

  defp add_code_path(path) do
    charlist_path = String.to_charlist(path)

    case charlist_path in :code.get_path() do
      true ->
        :ok

      false ->
        :code.add_patha(charlist_path)
        :ok
    end
  end
end
