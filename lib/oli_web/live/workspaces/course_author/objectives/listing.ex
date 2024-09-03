defmodule OliWeb.Workspaces.CourseAuthor.Objectives.Listing do
  use OliWeb, :html

  import OliWeb.Components.Common

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Workspaces.CourseAuthor.Objectives.Actions

  attr(:project_slug, :string, required: true)
  attr(:revision_history_link, :boolean, required: true)
  attr(:rows, :list, required: true)
  attr(:selected, :string, required: true)

  def render(assigns) do
    ~H"""
    <div id="accordion" class="accordion">
      <%= for {item, index} <- Enum.with_index(@rows) do %>
        <div id={item.slug} class="card max-w-full border mb-3 p-0">
          <div class="card-header d-flex justify-content-between p-2" id={"heading#{index}"}>
            <button
              class="flex-1 btn w-75 text-left"
              data-bs-toggle="collapse"
              data-bs-target={"#collapse#{index}"}
              aria-expanded="true"
              aria-controls={"collapse#{index}"}
              phx-click="set_selected"
              phx-value-slug={item.slug}
            >
              <%= item.title %>
            </button>
            <div class="d-flex flex-column font-weight-light small p-2 pr-4">
              <div>
                <i class="fa fa-cubes c0183 mr-1"></i><%= "Sub-Objectives #{item.sub_objectives_count}" %>
              </div>
              <div>
                <i class="far fa-file c0183 mr-1"></i><%= "Pages #{item.page_attachments_count}" %>
              </div>
              <div>
                <i class="fa fa-list mr-1"></i><%= "Activities #{item.activity_attachments_count}" %>
              </div>
              <.link
                :if={@revision_history_link}
                navigate={~p[/project/#{@project_slug}/history/slug/#{item.slug}]}
              >
                <i class="fas fa-history"></i> View revision history
              </.link>
            </div>
          </div>

          <div
            id={"collapse#{index}"}
            class={"collapse" <> if item.slug == @selected, do: " show", else: ""}
            aria-labelledby={"heading#{index}"}
            data-parent="#accordion"
          >
            <div class="card-body p-4">
              <div class="mb-3">
                <div class="font-bold">Sub-Objectives</div>
                <ul class="list-group list-group-flush">
                  <%= for sub_objective <- item.children do %>
                    <li :if={!is_nil(sub_objective)} class="list-group-item p-2 d-flex group/item">
                      <div class="py-1.5 w-75"><%= sub_objective.title %></div>
                      <div class="ml-2 invisible group-hover/item:visible">
                        <.button
                          variant={:tertiary}
                          size={:xs}
                          phx-click="display_edit_modal"
                          phx-value-slug={sub_objective.slug}
                        >
                          <i class="fas fa-i-cursor"></i> Rename
                        </.button>
                        <.button
                          variant={:danger}
                          size={:xs}
                          phx-click="delete"
                          phx-value-slug={sub_objective.slug}
                          phx-value-parent_slug={item.slug}
                        >
                          <i class="fas fa-trash-alt fa-lg"></i> Delete
                        </.button>
                      </div>
                    </li>
                  <% end %>
                </ul>
              </div>
              <div class="mb-3">
                <div class="font-bold">Pages</div>
                <ul class="list-group list-group-flush">
                  <%= for page <- item.page_attachments do %>
                    <li class="list-group-item p-2">
                      <a
                        href={Routes.resource_path(OliWeb.Endpoint, :edit, @project_slug, page.slug)}
                        target="_blank"
                        class="text-primary"
                      >
                        <%= page.title %>
                      </a>
                    </li>
                  <% end %>
                </ul>
              </div>

              <Actions.actions slug={item.slug} />
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
