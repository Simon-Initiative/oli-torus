defmodule Oli.Rendering.Page.Plaintext do
  @moduledoc """
  Implements the Html writer for Oli page rendering
  """
  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Page

  def page(%Context{} = context, model) do
    Elements.render(context, model, Elements.Plaintext)
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Plaintext)
  end
end
