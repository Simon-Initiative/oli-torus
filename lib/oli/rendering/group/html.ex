defmodule Oli.Rendering.Group.Html do
  @moduledoc """
  Implements the Html writer for content group rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error
  alias Oli.Utils.Purposes

  @behaviour Oli.Rendering.Group

  def group(%Context{} = context, next, %{"id" => id, "purpose" => purpose} = group) do
    purpose = purpose || "none"
    has_activity_reference = has_activity_reference?(group)

    trigger_button =
      case Map.get(group, "trigger") do
        nil ->
          ""

        trigger ->
          {:safe, trigger} =
            OliWeb.Common.React.component(
              context,
              "Components.TriggerGroupButton",
              %{
                "trigger" => trigger,
                "resourceId" => context.page_id,
                "sectionSlug" => context.section_slug
              },
              id: "trigger-group-#{context.page_id}-#{trigger["id"]}"
            )

          trigger
      end

    group_classes =
      ["group", "content-purpose", purpose, has_activity_reference && "has-activity-reference"]
      |> Enum.filter(& &1)
      |> Enum.join(" ")

    [
      ~s|<div id="#{id}" class="#{group_classes}"><div class="flex content-purpose-label"><div class="flex-grow-1">#{Purposes.label_for(purpose)}</div><div>#{trigger_button}</div></div><div class="content-purpose-content content">|,
      next.(),
      "</div></div>\n"
    ]
  end

  def group(%Context{} = context, next, params) do
    id = Map.get(params, "id", UUID.uuid4())
    purpose = Map.get(params, "purpose", "none")

    params =
      Map.put(params, "id", id)
      |> Map.put("purpose", purpose)

    group(context, next, params)
  end

  def elements(%Context{} = context, elements) do
    Elements.render(context, elements, Elements.Html)
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end

  defp has_activity_reference?(%{"children" => children}) when is_list(children) do
    Enum.any?(children, &match?(%{"type" => "activity-reference"}, &1))
  end

  defp has_activity_reference?(_), do: false
end
