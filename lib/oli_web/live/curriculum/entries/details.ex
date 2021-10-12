defmodule OliWeb.Curriculum.DetailsLive do
  @moduledoc """
  Curriculum item entry component.
  """

  use OliWeb, :live_component

  def render(assigns) do
    ~L"""
    <div class="entry-section d-flex flex-column col-4">
      <small class="text-muted">
        Created <%= Timex.format!(@child.resource.inserted_at, "{relative}", :relative) %>
      </small>
      <small class="text-muted">
        Updated <%= Timex.format!(@child.inserted_at, "{relative}", :relative) %> by <%= @child.author.name %>
      </small>
    </div>
    """
  end
end
