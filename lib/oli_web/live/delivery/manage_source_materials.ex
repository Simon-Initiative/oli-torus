defmodule OliWeb.Delivery.ManageSourceMaterials do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Updates.Subscriber
  alias Oli.Delivery.Updates.Worker
  alias Oli.Publishing
  alias Oli.Publishing.Publications.Publication
  alias Oli.Publishing.Publications.PublicationDiff
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Delivery.Updates.{ApplyUpdateModal, ProjectInfo}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount

  @title "Manage Source Materials"

  data base_project_details, :struct
  data current_publication, :map
  data projects_remixed, :map
  data section, :struct
  data updates, :map
  data updates_in_progress, :map

  @spec set_breadcrumbs(atom | %{:slug => any, optional(any) => any}, any) :: [...]
  def set_breadcrumbs(section, type) do
    type
    |> OliWeb.Sections.OverviewView.set_breadcrumbs(section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: @title,
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(
        %{"section_slug" => section_slug} = _params,
        session,
        socket
      ) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {user_type, _, section} ->
        updates = Sections.check_for_available_publication_updates(section)
        updates_in_progress = Sections.check_for_updates_in_progress(section)
        base_project_details = Course.get_project!(section.base_project_id)

        current_publication =
          Sections.get_current_publication(section.id, base_project_details.id)

        projects_remixed = Sections.get_projects_remixed(section.id, base_project_details.id)

        Subscriber.subscribe_to_update_progress(section.id)

        {:ok,
         assign(socket,
           title: @title,
           section: section,
           updates: updates,
           updates_in_progress: updates_in_progress,
           delivery_breadcrumb: true,
           breadcrumbs: set_breadcrumbs(section, user_type),
           base_project_details: base_project_details,
           current_publication: current_publication,
           projects_remixed: projects_remixed
         )}
    end
  end

  def render(assigns) do
    ~F"""
      {render_modal(assigns)}
      <div class="pb-5">

        <div class="card my-2">
          <div class="card-header d-flex align-items-center" id={"project_info_#{@base_project_details.id}"} phx-update="ignore">
            <h6 class="mb-0 mr-2">Base Project Info</h6>
            <i class="fa fa-info-circle" aria-hidden="true" data-toggle="tooltip" data-placement="right" title="Base project information"></i>
          </div>
          <ul class="list-group">
            <li class="list-group-item">
              <ProjectInfo
                project={@base_project_details}
                current_publication={@current_publication}
                newest_publication={newest_publication(@base_project_details.id, @updates)}
                updates={@updates}
                updates_in_progress={@updates_in_progress}
              />
            </li>
          </ul>
        </div>

        {#if not is_nil(@section.blueprint_id)}
          <div class="card my-2">
            <div class="card-header d-flex align-items-center" id={"product_info_#{@section.blueprint_id}"} phx-update="ignore">
              <h6 class="mb-0 mr-2">Product Info</h6>
              <i class="fa fa-info-circle" aria-hidden="true" data-toggle="tooltip" data-placement="right" title="Product information on which it is based"></i>
            </div>
            <ul class="list-group">
              <li class="list-group-item">
                <div class="card-body">
                  <div class="card-title">
                    <h5>{@section.blueprint.title}</h5>
                  </div>
                  <p class="card-text">{@section.blueprint.description}</p>
                </div>
              </li>
            </ul>
          </div>
        {/if}

        {#if Enum.count(@projects_remixed) > 0}
          <div class="card my-2">
            <div class="card-header d-flex align-items-center" id={"projects_remixed_1"} phx-update="ignore">
              <h6 class="mb-0 mr-2">Projects Remixed</h6>
              <i class="fa fa-info-circle" aria-hidden="true" data-toggle="tooltip" data-placement="right" title="Information about the projects that are remixed in this section"></i>
            </div>
            <ul class="list-group">
              {#for project <- @projects_remixed}
                <li class="list-group-item">
                  <ProjectInfo
                    project={project}
                    current_publication={project.publication}
                    newest_publication={newest_publication(project.id, @updates)}
                    updates={@updates}
                    updates_in_progress={@updates_in_progress}
                  />
                </li>
              {/for}
            </ul>
          </div>
        {/if}

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
    %{updates: updates, current_publication: current_publication} = socket.assigns

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
      ~F"""
        <ApplyUpdateModal {...@modal_assigns} />
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

  @spec handle_info(
          {:update_progress, any, any, any},
          atom
          | %{
              :assigns => %{
                :section => atom | %{:id => any, optional(any) => any},
                optional(any) => any
              },
              optional(any) => any
            }
        ) :: {:noreply, any}
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

E
