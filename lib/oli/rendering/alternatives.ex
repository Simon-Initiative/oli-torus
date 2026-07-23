defmodule Oli.Rendering.Alternatives do
  @moduledoc """
  This modules defines the rendering functionality for alternatives.
  """
  import Oli.Utils

  alias Oli.Rendering.Context
  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Resources.Alternatives.Selection

  @callback alternative(%Context{}, %Selection{}) :: [any()]
  @callback preference_selector(%Context{}, %{}) :: [any()]
  @callback error(%Context{}, %{}, {Atom.t(), String.t(), String.t()}) :: [any()]

  @doc """
  Renders alternatives based on the strategy specified. The content of the
  selected alternative(s) will be rendered.

  If more than one alternative is selected, the content of all selected alternatives
  will be concatenated as a single collection of rendered elements.
  """
  def render(
        %Context{
          enrollment: enrollment,
          user: user,
          institution_id: institution_id,
          project_id: project_id,
          publication_id: publication_id,
          section_id: section_id,
          section_slug: section_slug,
          project_slug: project_slug,
          activity_map: activity_map,
          mode: mode,
          alternatives_selector_fn: alternatives_selector_fn,
          alternatives_groups_fn: groups_fn,
          alternative_groups_by_id: alternative_groups_by_id,
          experiment_decisions: experiment_decisions
        } = context,
        %{"type" => "alternatives"} = element,
        writer
      ) do
    by_id = alternative_groups_by_id || load_alternative_groups_by_id(groups_fn)

    enrollment_id =
      case enrollment do
        nil -> nil
        e -> e.id
      end

    alternatives_selector_fn.(
      %AlternativesStrategyContext{
        enrollment_id: enrollment_id,
        user: user,
        institution_id: institution_id,
        project_id: project_id,
        publication_id: publication_id,
        section_id: section_id,
        section_slug: section_slug,
        mode: mode,
        project_slug: project_slug,
        activity_resource_ids: activity_resource_ids(activity_map),
        alternative_groups_by_id: by_id,
        experiment_decisions: experiment_decisions
      },
      element
    )
    |> render_selected_alternatives(context, writer)
    |> maybe_render_preference_selector(context, element, writer, by_id)
  end

  # Renders an error message if none of the signatures above match. Logging and rendering of errors
  # can be configured using the render_opts in context
  def render(%Context{render_opts: render_opts} = context, element, writer) do
    {error_id, error_msg} = log_error("Alternatives render error", element)

    if render_opts.render_errors do
      writer.error(context, element, {:invalid, error_id, error_msg})
    else
      []
    end
  end

  defp render_selected_alternatives(selected_alternatives, %Context{} = context, writer) do
    selected_alternatives
    |> Enum.flat_map(fn alternative ->
      writer.alternative(
        %Context{context | pagination_mode: "normal"},
        alternative
      )
    end)
  end

  defp maybe_render_preference_selector(
         rendered,
         context,
         element,
         writer,
         by_id
       ) do
    # IGNORE the strategy that is on the element in the page and
    # instead look up the strategy using the id from the alternatives resources
    case Map.get(by_id, element["alternatives_id"]).strategy do
      "user_section_preference" ->
        [writer.preference_selector(context, element) | rendered]

      _ ->
        rendered
    end
  end

  defp activity_resource_ids(activity_map) when is_map(activity_map), do: Map.keys(activity_map)
  defp activity_resource_ids(_activity_map), do: []

  defp load_alternative_groups_by_id(groups_fn) do
    {:ok, groups} = groups_fn.()

    Map.new(groups, fn group -> {group.id, group} end)
  end
end
