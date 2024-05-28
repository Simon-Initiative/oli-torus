defmodule Oli.Activities.Reports.Renderer do
  alias Oli.Rendering.Context

  @callback render(%Context{}, %{}) :: {:ok, term} | {:error, String.t()}

  def render(implementation, %Context{} = context, element) do
    implementation.render(context, element)
  end
end
