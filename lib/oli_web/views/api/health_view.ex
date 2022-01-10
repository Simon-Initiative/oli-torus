defmodule OliWeb.HealthView do
  use OliWeb, :view

  def render("index.json", %{status: status}) do
    %{status: status}
  end
end
