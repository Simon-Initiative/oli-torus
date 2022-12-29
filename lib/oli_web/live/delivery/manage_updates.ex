defmodule OliWeb.Delivery.ManageUpdates do
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
  alias OliWeb.Delivery.Updates.ApplyUpdateModal
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount

  @title "Manage Source Materials"

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
        current_publication = Sections.get_current_publication(section.id, base_project_details.id)
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
          <div class="card-header d-flex align-items-center justify-content-between">
            <h6 class="mb-0">Base Project Info</h6>
            <small>Base project information</small>
          </div>
          <div class="card-body">
            <div class="card-title">
              <div class="d-flex align-items-center">
                <h5 class="mb-0">{@base_project_details.title}</h5>
                <span class="badge badge-info ml-2">v{version_number(@current_publication)}</span>
              </div>
            </div>
            <p class="card-text">{@base_project_details.description}</p>
            <hr class="bg-light">
            {#case Enum.count(assigns.updates)}
              {#match 0}
                <h6>There are <b>no updates</b> available for this section.</h6>
              {#match 1}
                <h6>There is <b>one</b> update available for this section.</h6>
                {render_updates(assigns)}
              {#match number when number > 1}
                <h6>There are <b>{Enum.count(assigns.updates)}</b> updates available for this section.</h6>
                {render_updates(assigns)}
            {/case}
          </div>
        </div>

        {#if not is_nil(@section.blueprint_id)}
          <div class="card my-2">
            <div class="card-header d-flex align-items-center justify-content-between">
              <h6 class="mb-0">Product Info</h6>
              <small>Product information on which it is based</small>
            </div>
            <div class="card-body">
              <div class="card-title">
                <h5>{@section.blueprint.title}</h5>
              </div>
              <p class="card-text">{@section.blueprint.description}</p>
            </div>
          </div>
        {/if}

        {#if Enum.count(@projects_remixed) > 0}
          <div class="card my-2">
            <div class="card-header d-flex align-items-center justify-content-between">
              <h6 class="mb-0">Projects Remixed</h6>
              <small>Information about the projects that are remixed in this section</small>
            </div>
            <div class="card-body">
              <ul class="list-group">
                {#for project <- @projects_remixed}
                  <li class="list-group-item">
                    <div class="card-title d-flex align-items-center">
                      <h5 class="mb-0">{project.title}</h5>
                      <span class="badge badge-info ml-2">v{project.publication.edition}.{project.publication.major}.{project.publication.minor}</span>
                      {#if Enum.any?(@updates, fn {_, publication} -> publication.project_id == project.id end)}
                        <span class="badge badge-warning ml-2">Update available</span>
                      {/if}
                    </div>
                    <p class="card-text">{project.description}</p>
                  </li>
                {/for}
                </ul>
              </div>
          </div>
        {/if}

      </div>
    """
  end

  def version_number(%Publication{edition: edition, major: major, minor: minor}),
    do: "#{edition}.#{major}.#{minor}"

  def render_updates(%{updates: updates, updates_in_progress: updates_in_progress} = assigns) do
    ~F"""
      <div class="available-updates list-group my-3">
        {#for {_index, update} <- updates}
          <div class="list-group-item">
            <div class="d-flex justify-content-between align-items-center">
              <div class="d-flex align-items-center">
                <h5 class="mb-0">{update.project.title}</h5>
                <span class="badge badge-success ml-2">{"v#{update.edition}.#{update.major}.#{update.minor}"}</span>
              </div>
              {#if Map.has_key?(updates_in_progress, update.id)}
                <button type="button" class="btn btn-sm btn-primary" disabled>Update in progress...</button>
              {#else}
                <button type="button" class="btn btn-sm btn-primary"
                  phx-click="show_apply_update_modal"
                  phx-value-project-id={update.project_id}
                  phx-value-publication-id={update.id}>View Update</button>
              {/if}
            </div>
          </div>
       {/for}
      </div>
    """
  end

  def handle_event(
        "show_apply_update_modal",
        %{"project-id" => project_id, "publication-id" => publication_id},
        socket
      ) do
    %{updates: updates, current_publication: current_publication} = socket.assigns

    {_, newest_publication} = Enum.find(updates, fn {id, _} -> id == String.to_integer(project_id) end)

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
