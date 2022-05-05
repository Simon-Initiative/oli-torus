defmodule OliWeb.Api.PublisherView do
  use OliWeb, :view

  def render("show.json", %{publisher: publisher}) do
    %{publisher: render_one(publisher, __MODULE__, "publisher.json")}
  end

  def render("publisher.json", %{publisher: publisher}), do: publisher
end
