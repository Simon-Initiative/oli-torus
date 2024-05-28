defmodule Oli.Rendering.Report.Markdown do
  @moduledoc """
  Implements the Markdown writer for content survey rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Report

  def report(_context, _) do
    [
      "---\n",
      "##### Activity Report\n",

      "---\n"
    ]
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Markdown)
  end
end
