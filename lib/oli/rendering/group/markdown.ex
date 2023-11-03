defmodule Oli.Rendering.Group.Markdown do
  @moduledoc """
  Implements the Markdown writer for content group rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error
  alias Oli.Utils.Purposes

  @behaviour Oli.Rendering.Group

  def group(%Context{} = _context, next, %{"purpose" => purpose}) do
    [
      "---\n",
      "##### Group (purpose: #{Purposes.label_for(purpose)})\n",
      next.(),
      "---\n"
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
    Elements.render(context, elements, Elements.Markdown)
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Markdown)
  end
end
