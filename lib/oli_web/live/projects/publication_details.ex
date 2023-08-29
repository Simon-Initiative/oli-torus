defmodule OliWeb.Projects.PublicationDetails do
  use OliWeb, :html

  alias OliWeb.Common.Utils

  attr(:active_publication_changes, :any, required: true)
  attr(:ctx, :map, required: true)
  attr(:has_changes, :boolean, required: true)
  attr(:latest_published_publication, :any, required: true)
  attr(:parent_pages, :map, required: true)
  attr(:project, :map, required: true)

  def render(assigns) do
    ~H"""
    <h5 class="mb-0">Publication Details</h5>
    <div class="flex flex-row items-center">
      <div class="flex-1">
        Publish your project to give instructors access to the latest changes.
      </div>
      <div>
        <button
          class="btn btn-outline-primary whitespace-nowrap"
          phx-click="display_lti_connect_modal"
        >
          <i class="fa-solid fa-plug-circle-bolt"></i> Connect with LTI 1.3
        </button>
      </div>
    </div>
    <%= case @latest_published_publication do %>
      <% %{edition: current_edition, major: current_major, minor: current_minor} -> %>
        <div class="badge badge-secondary">
          Latest Publication: <%= Utils.render_version(current_edition, current_major, current_minor) %>
        </div>
      <% _ -> %>
    <% end %>

    <%= case {@has_changes, @active_publication_changes} do %>
      <% {true, nil} -> %>
        <h6 class="my-3"><strong>This project has not been published yet</strong></h6>
      <% {false, _} -> %>
        <h6 class="my-3">
          Published <strong> <%= Utils.render_date(@latest_published_publication, :published, @ctx) %></strong>.
          There are <strong>no changes</strong> since the latest publication.
        </h6>
      <% {true, changes} -> %>
        <div class="my-3">
          Last published <strong> <%= Utils.render_date(@latest_published_publication, :published, @ctx) %></strong>.
          There <%= if change_count(changes) == 1, do: "is", else: "are" %>
          <strong><%= change_count(changes) %></strong>
          pending <%= if change_count(changes) == 1, do: "change", else: "changes" %> since last publish:
        </div>
        <%= for {status, %{revision: revision}} <- Map.values(changes) do %>
          <div class="flex items-center my-2">
            <span class={"badge badge-secondary badge-#{status} mr-2"}><%= status %></span>
            <%= case status do %>
              <% :deleted -> %>
                <span><%= revision.title %></span>
              <% _ -> %>
                <span>
                  <%= OliWeb.Common.Links.resource_link(revision, @parent_pages, @project) %>
                </span>
            <% end %>
          </div>
        <% end %>
    <% end %>
    """
  end

  defp change_count(changes),
    do:
      changes
      |> Map.values()
      |> Enum.count()
end
