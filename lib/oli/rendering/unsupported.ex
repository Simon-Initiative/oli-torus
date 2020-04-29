defmodule Oli.Rendering.Unsupported do
  alias Oli.Rendering.Context

  @callback unsupported(%Context{}, %{}) :: [any()]

  def render(%Context{} = context, element, format) do
    format.unsupported(context, element)
  end

end
