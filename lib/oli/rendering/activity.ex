defmodule Oli.Rendering.Activity do
  alias Oli.Rendering.Context

  @callback activity(%Context{}, %{}) :: [any()]

  def render(%Context{} = context, element, format) do
    format.activity(context, element)
  end

end
