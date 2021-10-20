defmodule OliWeb.Delivery.Updates.Utils do
  use Phoenix.HTML
  import Phoenix.LiveView.Helpers

  alias Oli.Publishing.Publication

  def render_updates(%{updates: updates, updates_in_progress: updates_in_progress} = assigns) do
    ~L"""
      <div class="available-updates list-group my-3">
        <%= Enum.map(updates, fn {project_id, publication} -> %>
          <div class="list-group-item flex-column align-items-start">
            <%= render_update_details(assigns, publication) %>
            <div class="d-flex flex-row">
              <div class="flex-grow-1"></div>
              <%= if Map.has_key?(updates_in_progress, publication.id) do %>
                <button type="button" class="btn btn-sm btn-primary" disabled>Update in progress...</button>
              <% else %>
                <button type="button" class="btn btn-sm btn-primary"
                  phx-click="show_apply_update_modal"
                  phx-value-project-id="<%= project_id %>"
                  phx-value-publication-id="<%= publication.id %>">View Update</button>
              <% end %>
            </div>
          </div>
        <% end) %>
      </div>
    """
  end

  def render_update_details(
        assigns,
        %{
          published: published,
          description: description,
          edition: edition,
          major: major,
          minor: minor,
          project: project
        } = _publication
      ) do
    ~L"""
    <div class="d-flex w-100 justify-content-between">
      <h5 class="mb-1"><%= project.title %> <small><%= "v#{edition}.#{major}.#{minor}" %></small></h5>
      <small>Published <%= Timex.format!(published, "{relative}", :relative) %></small>
    </div>
    <p class="mb-1"><%= description %></p>
    """
  end

  def version_number(%Publication{edition: edition, major: major, minor: minor}) do
    "#{edition}.#{major}.#{minor}"
  end
end
