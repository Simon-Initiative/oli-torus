defmodule OliWeb.Curriculum.DetailsLive do
  @moduledoc """
  Curriculum item entry component.
  """

  use OliWeb, :live_component
  import OliWeb.Projects.Table, only: [time_ago: 2]

  def render(assigns) do
    ~L"""
    <div class="entry-section d-flex flex-column col-4">
      <small class="text-muted">
        Created <%= time_ago(assigns, @child.resource.inserted_at) %>
      </small>
      <small class="text-muted">
        Updated <%= time_ago(assigns, @child.inserted_at) %> by <%= @child.author.given_name %>
      </small>
    </div>
    """
  end
end
