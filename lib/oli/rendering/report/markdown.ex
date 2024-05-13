defmodule Oli.Rendering.Report.Markdown do
  @moduledoc """
  Implements the Markdown writer for content survey rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Report

  def survey(_context, next, _) do
    [
      "---\n",
      "##### Report\n",
      next.(),
      "---\n"
    ]
  end

  def elements(%Context{} = context, elements) do
    Elements.render(context, elements, Elements.Markdown)
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Markdown)
  end
end
