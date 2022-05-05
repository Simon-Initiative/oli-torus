defmodule Oli.Rendering.Group.Html do
  @moduledoc """
  Implements the Html writer for content group rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error
  alias Oli.Utils.Purposes

  @behaviour Oli.Rendering.Group

  def group(%Context{} = _context, next, %{"purpose" => purpose}) do
    [
      ~s|<div class="group content-purpose #{purpose}"><div class="content-purpose-label">#{Purposes.label_for(purpose)}</div><div class="content-purpose-content">|,
      next.(),
      "</div></div>\n"
    ]
  end

  def elements(%Context{} = context, elements) do
    Elements.render(context, elements, Elements.Html)
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end
end
