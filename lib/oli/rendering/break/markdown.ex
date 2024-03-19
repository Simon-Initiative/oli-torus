defmodule Oli.Rendering.Break.Markdown do
  @moduledoc """
  Implements the Markdown writer for content group rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Break

  def break(%Context{}, _break) do
    [
      "---\n"
    ]
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Markdown)
  end
end
