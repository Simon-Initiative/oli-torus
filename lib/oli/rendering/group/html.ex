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
    trigger_button =
      case Map.get(group, "trigger") do
        nil ->
          ""

        trigger ->
          {:safe, trigger} =
            OliWeb.Common.React.component(context, "Components.TriggerGroupButton", %{
              "trigger" => trigger,
              "resourceId" => context.page_id,
              "sectionSlug" => context.section_slug
            })

          trigger
      end

    [
      ~s|<div id="#{id}" class="group content-purpose #{purpose}"><div class="flex justify-between"><div class="content-purpose-label">#{Purposes.label_for(purpose)}</div><div>#{trigger_button}</div></div><div class="content-purpose-content content">|,
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
end
