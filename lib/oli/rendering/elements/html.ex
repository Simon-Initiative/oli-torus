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

  def break(%Context{} = context, element) do
    Break.render(context, element, Break.Html)
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end

  def paginate(%Context{} = context, {rendered, br_count}) do
    if br_count > 0 do
      IO.inspect(context.resource_attempt.state)

      {:safe, pagination_controls} =
        ReactPhoenix.ClientSide.react_component("Components.PaginationControls", %{
          forId: for_id(context),
          paginationMode: context.pagination_mode,
          sectionSlug: context.section_slug,
          pageAttemptGuid: context.resource_attempt.attempt_guid,
          initiallyVisible: extract_for(context.resource_attempt.state, for_id(context))
        })

      [
        ~s|<div class="paginated">|,
        ~s|<div class="elements">|,
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

  defp extract_for(state, id) do
    Map.get(state, "paginationState", %{})
    |> Map.get(id, [])
  end
end
