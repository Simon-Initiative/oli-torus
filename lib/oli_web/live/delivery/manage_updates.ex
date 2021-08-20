defmodule OliWeb.Delivery.ManageUpdates do
  use OliWeb, :live_view

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Publishing
  alias OliWeb.Common.ManualModal

  def mount(_params, %{"section" => section, "current_user" => current_user}, socket) do
    # only permit instructor level access
    if ContextRoles.has_role?(
         current_user,
         section.slug,
         ContextRoles.get_role(:context_instructor)
       ) do
      updates = Sections.check_for_available_publication_updates(section)

      socket =
        socket
        |> assign(:section, section)
        |> assign(:current_user, current_user)
        |> assign(:updates, updates)
        |> assign(:modal, nil)
        |> assign(:selection, nil)

      {:ok, socket}
    else
      {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :unauthorized))}
    end
  end

  def render(assigns) do
    %{
      updates: updates
    } = assigns

    ~L"""
      <div class="mb-2">
        <%= link to: Routes.page_delivery_path(OliWeb.Endpoint, :index, @section.slug) do %>
          <i class="las la-arrow-left"></i> Back
        <% end %>
      </div>

      <h2><%= dgettext("available_updates", "Available Updates") %></h2>

      <p class="my-4">
        <%= case Enum.count(updates) do %>
            <% 0 -> %>
              There are <b>no updates</b> available for this section.
            <% 1 -> %>
              There is <b>one</b> update available for this section:

              <%= render_updates(assigns) %>
            <% num_updates -> %>
              There are <b><%= num_updates %></b> updates available for this section:

              <%= render_updates(assigns) %>
        <% end %>
      </p>

    <%= case @modal do %>
      <% :apply_update -> %>
        <%= live_component ManualModal, title: "Update #{version_number(@selection.current_publication)} to #{version_number(@selection.newest_publication)}", modal_id: "applyUpdate", ok_action: "apply_update", ok_label: "Apply Update" do %>
          <p>
            Do you want to apply this update?
          </p>

          <%= case Enum.find(updates, fn {id, _} -> id == @selection.project_id end) do %>
            <% {_, publication} -> %>
            <div class="list-group-item flex-column align-items-start my-2">
              <%= render_update_details(assigns, publication) %>
            </div>

            <% _ -> %>
          <% end %>

          <p>
          The following materials from this project will be updated to match the latest publication:
          </p>

          <p>
            <%= for {status, %{revision: revision}}  <- Map.values(@selection.changes) do %>
              <div>
                <span class="badge badge-secondary badge-<%= status %>"><%= status %></span>
                <%= revision.title %>
              </div>
            <% end %>
          </p>

          <div class="alert alert-warning" role="alert">
            <b>This action cannot be undone.</b>
          </div>
        <% end %>

      <% _ -> %>

    <% end %>
    """
  end

  defp render_updates(%{updates: updates} = assigns) do
    ~L"""
      <div class="available-updates list-group my-3">
        <%= Enum.map(updates, fn {project_id, publication} -> %>
          <div class="list-group-item flex-column align-items-start">
            <%= render_update_details(assigns, publication) %>
            <div class="d-flex flex-row">
              <div class="flex-grow-1"></div>
              <button type="button" class="btn btn-sm btn-primary"
                phx-click="show_apply_update_modal"
                phx-value-project-id="<%= project_id %>"
                phx-value-publication-id="<%= publication.id %>">View Update</button>
            </div>
          </div>
        <% end) %>
      </div>
    """
  end

  defp render_update_details(
         assigns,
         %{
           published: published,
           description: description,
           major: major,
           minor: minor,
           patch: patch,
           project: project
         } = _publication
       ) do
    ~L"""
    <div class="d-flex w-100 justify-content-between">
      <h5 class="mb-1"><%= project.title %> <small><%= "#{major}.#{minor}.#{patch}" %></small></h5>
      <small>Published <%= Timex.format!(published, "{relative}", :relative) %></small>
    </div>
    <p class="mb-1"><%= description %></p>
    """
  end

  defp version_number(publication) do
    "#{publication.major}.#{publication.minor}.#{publication.patch}"
  end

  # handle any cancel events a modal might generate from being closed
  def handle_event("cancel_modal", _params, socket),
    do: {:noreply, assign(socket, modal: nil, selection: nil)}

  def handle_event(
        "show_apply_update_modal",
        %{"project-id" => project_id, "publication-id" => publication_id},
        socket
      ) do
    %{section: section} = socket.assigns
    current_publication = Sections.get_current_publication(section.id, project_id)
    newest_publication = Publishing.get_publication!(publication_id)

    changes =
      Publishing.diff_publications(current_publication, newest_publication)
      |> then(&:maps.filter(fn _, {status, _} -> status != :identical end, &1))

    {:noreply,
     assign(socket,
       modal: :apply_update,
       selection: %{
         current_publication: current_publication,
         newest_publication: newest_publication,
         project_id: String.to_integer(project_id),
         publication_id: String.to_integer(publication_id),
         changes: changes
       }
     )}
  end

  def handle_event("apply_update", _, socket) do
    %{
      section: section,
      selection: %{project_id: project_id, publication_id: publication_id}
    } = socket.assigns

    publication = Publishing.get_publication!(publication_id)

    Sections.update_section_project_publication(section, project_id, publication_id)
    Sections.rebuild_section_resources(section: section, publication: publication)

    {:noreply,
     push_redirect(socket,
       to: Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.ManageUpdates, section.slug)
     )}
  end
end
