defmodule Oli.Scenarios.Directives.MediaHandler do
  @moduledoc """
  Handles media directives to upload files to a project's media library.
  """

  alias Oli.Scenarios.DirectiveTypes.MediaDirective
  alias Oli.Scenarios.Engine
  alias Oli.Authoring.MediaLibrary

  def handle(%MediaDirective{project: project_name, path: path, mime: mime}, state) do
    try do
      built_project =
        Engine.get_project(state, project_name) ||
          raise "Project '#{project_name}' not found in scenario state"

      resolved_path =
        if Path.type(path) == :relative and state.current_dir do
          Path.join(state.current_dir, path)
        else
          path
        end

      contents = File.read!(resolved_path)

      file_name =
        case {Path.extname(resolved_path), mime} do
          {"", mime_val} when is_binary(mime_val) ->
            ext = MIME.extensions(mime_val) |> List.first()
            base = Path.basename(resolved_path)
            if ext, do: "#{base}.#{ext}", else: base

          _ ->
            Path.basename(resolved_path)
        end

      case MediaLibrary.add(built_project.project.slug, file_name, contents) do
        {:ok, _media_item} ->
          {:ok, state}

        {:duplicate, _media_item} ->
          # Treat duplicate content as success
          {:ok, state}

        {:error, {:file_exists}} ->
          # Name collision but different content; let caller decide—treat as error
          raise "A media item named '#{file_name}' already exists in project '#{project_name}'"

        {:error, reason} ->
          raise "Media upload failed: #{inspect(reason)}"
      end
    rescue
      e ->
        {:error,
         "Failed to upload media for project '#{project_name}' from '#{path}': #{Exception.message(e)}"}
    end
  end
end
