defmodule Oli.Math.Gleam do
  @moduledoc false

  @reload_project_modules Mix.env() == :dev
  @code_paths_key {__MODULE__, :code_paths}

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
    maybe_reload_project_modules(paths)
    ensure_exported!(module, function, length(args), paths)
    apply(module, function, args)
  end

  defp ensure_gleam_code_path! do
    case :persistent_term.get(@code_paths_key, :missing) do
      :missing -> discover_gleam_code_paths!()
      paths -> paths
    end
  end

  defp discover_gleam_code_paths! do
    # The Mix project compiles Gleam and its Gleam package dependencies under
    # `gleam/build`. Dev/test use the source-tree build; releases copy the
    # Erlang build output under RELEASE_ROOT so deployed nodes can load it.
    paths =
      gleam_build_roots()
      |> Enum.flat_map(fn root ->
        root
        |> Path.join("*/erlang/*/ebin")
        |> Path.wildcard()
      end)
      |> prefer_project_ebin_last()
      |> tap(fn paths -> Enum.each(paths, &add_code_path/1) end)

    :persistent_term.put(@code_paths_key, paths)
    paths
  end

  defp gleam_build_roots do
    [
      System.get_env("OLI_GLEAM_BUILD_ROOT"),
      release_root_gleam_build_root(),
      release_app_gleam_build_root(),
      source_tree_gleam_build_root()
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp release_root_gleam_build_root do
    case System.get_env("RELEASE_ROOT") do
      nil -> nil
      release_root -> Path.join(release_root, "gleam/build")
    end
  end

  defp release_app_gleam_build_root do
    try do
      Application.app_dir(:oli, "../../gleam/build")
      |> Path.expand()
    rescue
      ArgumentError -> nil
    end
  end

  defp source_tree_gleam_build_root do
    Path.expand("../../../gleam/build", __DIR__)
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

  defp maybe_reload_project_modules(paths) do
    if @reload_project_modules do
      paths
      |> Enum.filter(&String.ends_with?(&1, "/oli/ebin"))
      |> Enum.flat_map(fn path -> Path.wildcard(Path.join(path, "*.beam")) end)
      |> Enum.each(fn beam_path ->
        beam_path
        |> Path.basename(".beam")
        |> String.to_atom()
        |> reload_module()
      end)
    end
  end

  defp prefer_project_ebin_last(paths) do
    Enum.sort_by(paths, fn path ->
      case String.ends_with?(path, "/oli/ebin") do
        true -> 1
        false -> 0
      end
    end)
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
