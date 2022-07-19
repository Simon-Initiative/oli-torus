defmodule Oli.Rendering.Break.Html do
  @moduledoc """
  Implements the Html writer for content group rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Break

  def break(%Context{}, _break) do
    [
      ~s|<div class="content-break"></div>|
    ]
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end
end
