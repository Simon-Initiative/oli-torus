defmodule Oli.Scenarios.Playwright.BioBeyondDesignerPlanetHooks do
  @moduledoc """
  Playwright scenario hooks for seeding the BioBeyond Designer Planet export.

  The export zip and answer key are intentionally supplied by the Playwright
  runner for now so the public repo does not become the long-term source of
  private course content or correct answers.
  """

  alias Oli.Interop.Ingest
  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, ExtendedBuiltProject}
  alias Oli.Scenarios.Engine

  @project_name "biobeyond_designer_planet_project"
  @default_zip_path "export_biobeyond_accessible_version (2).zip"

  def import_project(%ExecutionState{} = state) do
    zip_path = resolve_zip_path(state)
    author = Engine.get_user(state, "playwright_author") || state.current_author

    if is_nil(author) do
      raise "BioBeyond Designer Planet seed requires a current author"
    end

    unless File.exists?(zip_path) do
      raise "BioBeyond Designer Planet export zip not found at #{zip_path}"
    end

    {:ok, project} = Ingest.ingest(zip_path, author)
    working_pub = Publishing.project_working_publication(project.slug)

    built_project = %ExtendedBuiltProject{
      project: Repo.preload(project, :authors),
      working_pub: working_pub,
      root: nil,
      id_by_title: %{},
      rev_by_title: %{},
      sections: []
    }

    Engine.put_project(state, @project_name, built_project)
  end

  defp resolve_zip_path(%ExecutionState{} = state) do
    configured =
      state.params
      |> Map.get("PROJECT_ZIP_PATH")
      |> case do
        value when is_binary(value) and value != "" -> value
        _ -> @default_zip_path
      end

    candidates =
      [
        configured,
        Path.expand(configured, File.cwd!()),
        state |> Map.get(:current_dir) |> expand_from_current_dir(configured)
      ]
      |> Enum.reject(&is_nil/1)

    Enum.find(candidates, &File.exists?/1) || Path.expand(configured, File.cwd!())
  end

  defp expand_from_current_dir(nil, _path), do: nil
  defp expand_from_current_dir(current_dir, path), do: Path.expand(path, current_dir)
end
