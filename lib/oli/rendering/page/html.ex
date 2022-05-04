defmodule Oli.Rendering.Page.Html do
  @moduledoc """
  Implements the Html writer for Oli page rendering
  """
  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Page

  def page(%Context{} = context, model) do
    {rendered, _br_count} = Elements.render(context, model, Elements.Html)

    rendered
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end
end
