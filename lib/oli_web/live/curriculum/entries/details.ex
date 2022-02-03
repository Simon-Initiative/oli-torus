defmodule OliWeb.Curriculum.DetailsLive do
  @moduledoc """
  Curriculum item entry component.
  """

  use OliWeb, :live_component

  def render(assigns) do
    ~L"""
    <div class="entry-section d-flex flex-column col-4">
      <small class="text-muted">
        Created <%= date(@child.resource.inserted_at, @context) %>
      </small>
      <small class="text-muted">
        Updated <%= date(@child.inserted_at, @context) %> by <%= @child.author.name %>
      </small>
    </div>
    """
  end
end
