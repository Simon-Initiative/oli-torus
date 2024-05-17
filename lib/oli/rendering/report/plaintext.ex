defmodule Oli.Rendering.Report.Plaintext do
  @moduledoc """
  Implements the Plaintext writer for content survey rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Report

  def report(%Context{} = _context, next, %{"id" => id}) do
    [
      "[Report #{id}          ]",
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
