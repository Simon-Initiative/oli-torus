defmodule OliWeb.Delivery.ManageSourceMaterials do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Updates.{Subscriber, Worker}
  alias Oli.Publishing
  alias Oli.Publishing.Publications.{Publication, PublicationDiff}
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Delivery.ManageSourceMaterials.{ApplyUpdateModal, ProjectInfo, ProjectCard}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount

  def set_breadcrumbs(section, type) do
    type
    |> OliWeb.Sections.OverviewView.set_breadcrumbs(section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Manage Source Materials",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(
        params,
        session,
        socket
      ) do
    section_slug =
      case params do
        :not_mounted_at_router -> Map.get(session, "section_slug")
        _ -> Map.get(params, "section_slug")
      end

    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {user_type, _, section} ->
        updates = Sections.check_for_available_publication_updates(section)
        updates_in_progress = Sections.check_for_updates_in_progress(section)
        base_project_details = Course.get_project!(section.base_project_id)

        current_publication =
          Sections.get_current_publication(section.id, base_project_details.id)

        remixed_projects = Sections.get_remixed_projects(section.id, base_project_details.id)

        Subscriber.subscribe_to_update_progress(section.id)

        {:ok,
         assign(socket,
           section: section,
           updates: updates,
           updates_in_progress: updates_in_progress,
           breadcrumbs: set_breadcrumbs(section, user_type),
           base_project_details: base_project_details,
           current_publication: current_publication,
           remixed_projects: remixed_projects
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <%= render_modal(assigns) %>
    <div class="container mx-auto pb-5">
      <ProjectCard.render
        id={"project_info_#{@base_project_details.id}"}
        title="Base Project Info"
        tooltip="Information about the base project curriculum"
      >
        <ProjectInfo.render
          project={@base_project_details}
          current_publication={@current_publication}
          newest_publication={newest_publication(@base_project_details.id, @updates)}
          updates={@updates}
          updates_in_progress={@updates_in_progress}
        />
      </ProjectCard.render>
      <%= if not is_nil(@section.blueprint_id) do %>
        <ProjectCard.render
          id={"product_info_#{@section.blueprint_id}"}
          title="Product Info"
          tooltip="Information about the product on which this section is based"
        >
          <div class="card-title">
            <h5><%= @section.blueprint.title %></h5>
          </div>
          <p class="card-text"><%= @section.blueprint.description %></p>
        </ProjectCard.render>
      <% end %>

      <%= if Enum.count(@remixed_projects) > 0 do %>
        <ProjectCard.render
          id="remixed_projects_1"
          title="Remixed Projects Info"
          tooltip="Information about the projects that have been remixed into this section"
        >
          <ul class="list-group">
            <%= for project <- @remixed_projects do %>
              <li class="list-group-item">
                <ProjectInfo.render
                  project={project}
                  current_publication={project.publication}
                  newest_publication={newest_publication(project.id, @updates)}
                  updates={@updates}
                  updates_in_progress={@updates_in_progress}
                />
              </li>
            <% end %>
          </ul>
        </ProjectCard.render>
      <% end %>
    </div>
    """
  end

  defp newest_publication(project_id, updates) do
    case Enum.find(updates, fn {id, _} -> id == project_id end) do
      {_project, %Publication{} = newest_publication} -> newest_publication
      nil -> nil
    end
  end

  def handle_event(
        "show_apply_update_modal",
        %{"project-id" => project_id, "publication-id" => publication_id},
        socket
      ) do
    %{updates: updates, section: section} = socket.assigns

    current_publication = Sections.get_current_publication(section.id, project_id)

    newest_publication = newest_publication(String.to_integer(project_id), updates)

    %PublicationDiff{changes: changes} =
      Publishing.diff_publications(current_publication, newest_publication)

    modal_assigns = %{
      id: "apply_update_modal",
      current_publication: current_publication,
      newest_publication: newest_publication,
      project_id: String.to_integer(project_id),
      changes: changes,
      updates: updates
    }

    modal = fn assigns ->
      ~H"""
      <ApplyUpdateModal.render
        changes={@modal_assigns.changes}
        current_publication={@modal_assigns.current_publication}
        id={@modal_assigns.id}
        newest_publication={@modal_assigns.newest_publication}
        project_id={@modal_assigns.project_id}
        updates={@modal_assigns.updates}
      />
      """
    end

    {:noreply,
     socket
     |> assign(publication_id: String.to_integer(publication_id))
     |> show_modal(
       modal,
       modal_assigns: modal_assigns
     )}
  end

  def handle_event("apply_update", _, socket) do
    %{
      section: section,
      publication_id: publication_id,
      updates_in_progress: updates_in_progress
    } = socket.assigns

    %{"section_slug" => section.slug, "publication_id" => publication_id}
    |> Worker.new()
    |> Oban.insert!()

    updates_in_progress = Map.put_new(updates_in_progress, publication_id, true)

    {:noreply,
     socket
     |> assign(updates_in_progress: updates_in_progress)
     |> hide_modal(modal_assigns: nil)}
  end

  def handle_info({:update_progress, section_id, publication_id, :complete}, socket) do
    %{section: section} = socket.assigns

    if section_id == section.id do
      %{
        updates: updates,
        updates_in_progress: updates_in_progress
      } = socket.assigns

      %{project_id: project_id} = Publishing.get_publication!(publication_id)

      {:noreply,
       assign(socket,
         updates: Map.delete(updates, project_id),
         updates_in_progress: Map.delete(updates_in_progress, publication_id)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:update_progress, section_id, publication_id, _progress}, socket) do
    %{section: section} = socket.assigns

    if section_id == section.id do
      %{updates_in_progress: updates_in_progress} = socket.assigns

      updates_in_progress = Map.put_new(updates_in_progress, publication_id, true)

      {:noreply, assign(socket, updates_in_progress: updates_in_progress)}
    else
      {:noreply, socket}
    end
  end
end
