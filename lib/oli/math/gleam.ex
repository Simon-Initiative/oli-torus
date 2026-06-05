defmodule Oli.Math.Gleam do
  @moduledoc false

  @reload_project_modules Mix.env() == :dev
  @code_paths_key {__MODULE__, :code_paths}

  defmodule MissingFunctionError do
    defexception [:module, :function, :arity, :paths, :loaded_path, :exports, :load_result]

    @impl true
    def message(%{
          module: module,
          function: function,
          arity: arity,
          paths: paths,
          loaded_path: loaded_path,
          exports: exports,
          load_result: load_result
        }) do
      """
      Gleam function #{inspect(module)}.#{function}/#{arity} is unavailable.
      Run `cd gleam && gleam build --target erlang`, then restart or retry the dev server.
      Searched ebin paths: #{Enum.join(paths, ", ")}
      Loaded path: #{inspect(loaded_path)}
      Load result: #{inspect(load_result)}
      Loaded exports: #{inspect(exports)}
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
      |> Enum.with_index()
      |> Enum.flat_map(fn {root, root_index} ->
        root
        |> Path.join("*/erlang/*/ebin")
        |> Path.wildcard()
        |> Enum.map(&{&1, root_index})
      end)
      |> prefer_project_ebin_first()
      |> Enum.map(fn {path, _root_index} -> path end)
      |> tap(fn paths ->
        add_code_paths(paths)
        load_modules_from_paths(paths)
      end)

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
      Application.app_dir(:oli, "../../../gleam/build")
      |> Path.expand()
    rescue
      ArgumentError -> nil
    end
  end

  defp source_tree_gleam_build_root do
    Path.expand("../../../gleam/build", __DIR__)
  end

  defp ensure_exported!(module, function, arity, paths) do
    ensure_module_loaded(module, paths)

    if function_exported?(module, function, arity) do
      :ok
    else
      load_result = load_module_from_paths(module, paths)

      unless function_exported?(module, function, arity) do
        raise MissingFunctionError,
          module: module,
          function: function,
          arity: arity,
          paths: paths,
          loaded_path: :code.which(module),
          exports: loaded_exports(module),
          load_result: load_result
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

  defp prefer_project_ebin_first(paths) do
    Enum.sort_by(paths, fn {path, root_index} ->
      case String.ends_with?(path, "/oli/ebin") do
        true -> {0, root_index, path}
        false -> {1, root_index, path}
      end
    end)
  end

  defp ensure_module_loaded(module, paths) do
    case :code.is_loaded(module) do
      false -> load_module_from_paths(module, paths)
      _ -> {:module, module}
    end
  end

  defp load_module_from_paths(module, paths) do
    case module_beam_path(module, paths) do
      nil ->
        :code.ensure_loaded(module)

      beam_path ->
        :code.purge(module)
        :code.delete(module)

        load_module_from_path(beam_path)
    end
  end

  defp load_modules_from_paths(paths) do
    paths
    |> module_beam_paths()
    |> Enum.each(fn {module, beam_path} ->
      case :code.is_loaded(module) do
        false -> load_module_from_path(beam_path)
        _ -> :ok
      end
    end)
  end

  defp module_beam_paths(paths) do
    paths
    |> Enum.flat_map(fn path ->
      path
      |> Path.join("*.beam")
      |> Path.wildcard()
      |> Enum.map(fn beam_path ->
        module =
          beam_path
          |> Path.basename(".beam")
          |> String.to_atom()

        {module, beam_path}
      end)
    end)
    |> Enum.uniq_by(fn {module, _beam_path} -> module end)
  end

  defp module_beam_path(module, paths) do
    beam_file = "#{module}.beam"

    Enum.find_value(paths, fn path ->
      beam_path = Path.join(path, beam_file)

      if File.regular?(beam_path) do
        beam_path
      end
    end)
  end

  defp load_module_from_path(beam_path) do
    beam_path
    |> Path.rootname()
    |> String.to_charlist()
    |> :code.load_abs()
  end

  defp loaded_exports(module) do
    if function_exported?(module, :module_info, 1) do
      module.module_info(:exports)
    else
      []
    end
  end

  defp reload_module(module) do
    :code.purge(module)
    :code.delete(module)
    :code.ensure_loaded(module)
  end

  defp add_code_paths(paths) do
    paths
    |> Enum.reverse()
    |> Enum.each(&add_code_path/1)
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
