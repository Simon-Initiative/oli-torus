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
          section_slug: section_slug,
          project_slug: project_slug,
          mode: mode,
          alternatives_selector_fn: alternatives_selector_fn,
          alternatives_groups_fn: groups_fn
        } = context,
        %{"type" => "alternatives"} = element,
        writer
      ) do

    {:ok, groups} = groups_fn.()
    by_id = Enum.reduce(groups, %{}, fn r, m -> Map.put(m, r.id, r) end)

    enrollment_id = case enrollment do
      nil -> nil
      e -> e.id
    end

    alternatives_selector_fn.(
      %AlternativesStrategyContext{enrollment_id: enrollment_id, user: user, section_slug: section_slug, mode: mode, project_slug: project_slug, alternative_groups_by_id: by_id},
      element
    )
    |> render_selected_alternatives(context, writer)
    |> maybe_render_preference_selector(context, element, writer)
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

  defp render_selected_alternatives(selected_alternatives, context, writer) do
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
         %{"strategy" => "user_section_preference"} = element,
         writer
       ) do
    [writer.preference_selector(context, element) | rendered]
  end

  defp maybe_render_preference_selector(rendered, _, _, _writer), do: rendered
end
