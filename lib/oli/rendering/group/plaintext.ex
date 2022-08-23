defmodule Oli.Rendering.Group.Plaintext do
  @moduledoc """
  Implements the Plaintext writer for content group rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error
  alias Oli.Utils.Purposes

  @behaviour Oli.Rendering.Group

  def group(%Context{} = _context, next, %{"id" => id, "purpose" => purpose}) do
    [
      "[#{Purposes.label_for(purpose)} #{id}         ]",
      next.(),
      "------------------------------------------\n"
    ]
  end

  def elements(%Context{} = context, elements) do
    Elements.render(context, elements, Elements.Plaintext)
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Plaintext)
  end
end
