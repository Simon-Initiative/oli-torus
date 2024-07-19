defmodule OliWeb.Projects.VersioningDetails do
  use OliWeb, :html

  alias OliWeb.Common.Utils

  attr(:active_publication, :any, required: true)
  attr(:active_publication_changes, :any, required: true)
  attr(:auto_update_sections, :boolean, default: true)
  attr(:changeset, :any, required: true)
  attr(:has_changes, :boolean, required: true)
  attr(:latest_published_publication, :any, required: true)
  attr(:project, :map, required: true)
  attr(:publish_active, :any, required: true)
  attr(:push_affected, :map, required: true)
  attr(:version_change, :any, required: true)
  attr(:form_changed, :any, required: true)
  attr(:description, :string, default: "")

  def render(assigns) do
    ~H"""
    <div class="my-4 border-t pt-3">
      <.form
        id="versioning-details-form"
        for={@changeset}
        phx-submit={@publish_active}
        phx-change={@form_changed}
      >
        <%= if @has_changes && @active_publication_changes do %>
          <h5>Versioning Details</h5>
          <p>The version number is automatically determined by the nature of the changes.</p>
          <%= case @version_change do %>
            <% {change_type, _} when change_type == :major or change_type == :minor -> %>
              <div class="py-2">
                <ul class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white">
                  <li class="px-6 py-2 border-b border-gray-200 dark:border-gray-700 w-full rounded-t-lg">
                    <div class="flex flex-row p-2">
                      <div class="w-10 py-3 pr-2">
                        <%= if change_type == :major do %>
                          <i class="fa-solid fa-arrow-right fa-xl text-blue-500"></i>
                        <% end %>
                      </div>
                      <div class="flex-1">
                        <p>
                          Major
                          <%= case {@version_change, @latest_published_publication} do %>
                            <% {{:major, {edition, major, minor}}, %{edition: current_edition, major: current_major, minor: current_minor}} -> %>
                              <small class="ml-1">
                                <%= Utils.render_version(
                                  current_edition,
                                  current_major,
                                  current_minor
                                ) %>
                                <i class="fas fa-arrow-right mx-2"></i>
                                <%= Utils.render_version(edition, major, minor) %>
                              </small>
                            <% _ -> %>
                          <% end %>
                        </p>
                        <small>
                          Changes alter the structure of materials such as additions and deletions.
                        </small>
                      </div>
                    </div>
                  </li>

                  <li class="px-6 py-2 w-full rounded-t-lg">
                    <div class="flex flex-row p-2">
                      <div class="w-10 py-3 pr-2">
                        <%= if change_type == :minor do %>
                          <i class="fa-solid fa-arrow-right fa-xl text-blue-500"></i>
                        <% end %>
                      </div>
                      <div class="flex-1">
                        <p>
                          Minor
                          <%= case {@version_change, @latest_published_publication} do %>
                            <% {{:minor, {edition, major, minor}}, %{edition: current_edition, major: current_major, minor: current_minor}} -> %>
                              <small class="ml-1">
                                <%= Utils.render_version(
                                  current_edition,
                                  current_major,
                                  current_minor
                                ) %>
                                <i class="fas fa-arrow-right mx-2"></i>
                                <%= Utils.render_version(edition, major, minor) %>
                              </small>
                            <% _ -> %>
                          <% end %>
                        </p>
                        <small>
                          Changes include small portions of reworked materials, grammar and spelling fixes.
                        </small>
                      </div>
                    </div>
                  </li>
                </ul>
              </div>
            <% {:no_changes, _} -> %>
          <% end %>
          <.input
            type="textarea"
            field={@changeset[:description]}
            value={@description}
            class="form-control"
            rows="3"
            placeholder="Enter a short description of these changes..."
            required={true}
            autocomplete="off"
          />
        <% else %>
          <%= if is_nil(@active_publication_changes) do %>
            <.input class="hidden" field={@changeset[:description]} value="Initial publish" />
          <% end %>
        <% end %>

        <%= if @active_publication_changes do %>
          <div class="my-3">
            <.input
              class="form-check-input"
              type="checkbox"
              field={@changeset[:auto_push_update]}
              value={@auto_update_sections}
              label="Automatically push this publication update to all products and sections"
            />
          </div>
        <% end %>

        <%= if @auto_update_sections do %>
          <div class="alert alert-warning" role="alert">
            <%= if @push_affected.section_count > 0 or @push_affected.product_count > 0 do %>
              <h6>This force push update will affect:</h6>
              <ul class="mb-0">
                <li><%= @push_affected.section_count %> course section(s)</li>
                <li><%= @push_affected.product_count %> product(s)</li>
              </ul>
            <% else %>
              This force push update will not affect any product or course section.
            <% end %>
          </div>
        <% end %>

        <div class="form-group">
          <.input
            class="hidden"
            field={@changeset[:active_publication_id]}
            value={@active_publication.id}
          />
          <button
            type="submit"
            id="button-publish"
            class="btn btn-primary"
            disabled:!{@has_changes},
            phx_disable_with="Publishing..."
          >
            Publish
          </button>
          <%= case @version_change do %>
            <% {:no_changes, _} -> %>
            <% {_, {edition, major, minor}} -> %>
              <span class="ml-2"><%= Utils.render_version(edition, major, minor) %></span>
            <% _ -> %>
          <% end %>
        </div>
      </.form>
    </div>
    """
  end
end
