defmodule Oli.Rendering.Elements.Html do
  @moduledoc """
  Implements the Html writer for rendering errors
  """
  @behaviour Oli.Rendering.Elements

  alias Oli.Rendering.Context
  alias Oli.Rendering.Content
  alias Oli.Rendering.Activity
  alias Oli.Rendering.Group
  alias Oli.Rendering.Survey
  alias Oli.Rendering.Report
  alias Oli.Rendering.Alternatives
  alias Oli.Rendering.Break
  alias Oli.Rendering.Error

  def content(%Context{} = context, element) do
    Content.render(context, element, Content.Html)
  end

  def activity(%Context{} = context, element) do
    Activity.render(context, element, Activity.Html)
  end

  def group(%Context{} = context, element) do
    Group.render(context, element, Group.Html)
  end

  def survey(%Context{} = context, element) do
    Survey.render(context, element, Survey.Html)
  end

  def report(%Context{} = context, element) do
    Report.render(context, element, Report.Html)
  end

  def alternatives(%Context{} = context, element) do
    Alternatives.render(context, element, Alternatives.Html)
  end

  def break(%Context{} = context, element) do
    Break.render(context, element, Break.Html)
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end

  def paginate(%Context{} = context, {rendered, br_count}) do
    if br_count > 0 do
      {:safe, pagination_controls} =
        OliWeb.Common.React.component(context, "Components.PaginationControls", %{
          forId: for_id(context),
          paginationMode: context.pagination_mode,
          sectionSlug: context.section_slug,
          pageAttemptGuid: page_attempt_guid(context.resource_attempt),
          initiallyVisible: extract_for(context.resource_attempt, for_id(context))
        })

      [
        ~s|<div class="paginated">|,
        ~s|<div class="elements content">|,
        rendered,
        ~s|</div>|,
        pagination_controls,
        ~s|</div>|
      ]
    else
      rendered
    end
  end

  defp for_id(%Context{survey_id: nil, group_id: nil, page_id: id}), do: id
  defp for_id(%Context{survey_id: nil, group_id: id}), do: id
  defp for_id(%Context{survey_id: id}), do: id

  defp extract_for(nil, _), do: []

  defp extract_for(resource_attempt, id) do
    case resource_attempt.state do
      nil ->
        []

      state ->
        Map.get(state, "paginationState", %{})
        |> Map.get(id, [])
    end
  end

  defp page_attempt_guid(nil), do: ""
  defp page_attempt_guid(resource_attempt), do: resource_attempt.attempt_guid
end
