defmodule OliWeb.Delivery.Updates.ApplyUpdateModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Delivery.Updates.Utils

  def render(assigns) do
    ~H"""
    <div class="modal fade show" id={@id} tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Apply Update</h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
              <p>
                Do you want to apply this update from <%= version_number(@current_publication) %> to <%= version_number(@newest_publication) %>
              </p>

              <%= case Enum.find(@updates, fn {id, _} -> id == @project_id end) do %>
                <% {_, publication} -> %>
                <div class="border rounded p-3 flex-column align-items-start my-2">
                  <%= render_update_details(assigns, publication) %>
                </div>

                <% _ -> %>
              <% end %>

              <p>
              The following materials from this project will be updated to match the latest publication:
              </p>

              <p>
                <%= for {status, %{revision: revision}}  <- Map.values(@changes) do %>
                  <div>
                    <span class={"badge badge-secondary badge-#{status}"}><%= status %></span>
                    <%= revision.title %>
                  </div>
                <% end %>
              </p>

              <div class="alert alert-warning my-2" role="alert">
                <b>This action cannot be undone.</b>
              </div>
            </div>
            <div class="modal-footer flex justify-end">
              <button type="button" class="btn btn-link" data-bs-dismiss="modal">Cancel</button>
              <button
                phx-click="apply_update"
                phx-key="enter"
                class="btn btn-warning ml-2">
                Apply Update
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end
end
