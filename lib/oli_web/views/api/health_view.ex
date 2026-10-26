defmodule OliWeb.HealthView do
  use OliWeb, :view

  @doc "Renders only the public liveness status."
  def render("index.json", %{status: status}) do
    %{status: status}
  end
end
