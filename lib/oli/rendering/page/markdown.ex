defmodule Oli.Rendering.Page.Markdown do
  @moduledoc """
  Implements the Markdown writer for Oli page rendering
  """
  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Page

  def page(%Context{} = context, model) do
    Elements.render(context, model, Elements.Markdown)
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Markdown)
  end
end
