defmodule OliWeb.Sections.OverviewView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb, DeleteModalNoConfirmation}
  alias OliWeb.Common.Properties.{Groups, Group, ReadOnly}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.EnrollmentBrowseOptions
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.{Instructors, Mount, UnlinkSection}
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Collaboration
  alias OliWeb.Projects.RequiredSurvey

  prop(user, :any)
  data(modal, :any, default: nil)
  data(breadcrumbs, :any)
  data(title, :string, default: "Section Details")
  data(section, :any, default: nil)
  data(instructors, :list, default: [])
  data(updates_count, :integer)
  data(submission_count, :integer)
  data(section_has_student_data, :boolean)

  def set_breadcrumbs(:admin, section) do
    OliWeb.Sections.SectionsView.set_breadcrumbs()
    |> breadcrumb(section)
  end

  def set_breadcrumbs(_, section) do
    breadcrumb([], section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Manage Section",
          link:
            Routes.live_path(
              OliWeb.Endpoint,
              OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
              section.slug,
              :manage
            )
        })
      ]
  end

  def mount(_params, %{"section_slug" => section_slug} = session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, user, section} ->
        updates_count =
          Sections.check_for_available_publication_updates(section)
          |> Enum.count()

        show_required_section_config =
          if section.required_survey_resource_id != nil or
               Sections.get_parent_project_survey(section.slug) do
            true
          else
            false
          end

        %{slug: revision_slug} = DeliveryResolver.root_container(section.slug)

        {:ok, collab_space_config} =
          Collaboration.get_collab_space_config_for_page_in_section(
            revision_slug,
            section.slug
          )

        {:ok,
         assign(socket,
           is_system_admin: type == :admin,
           is_lms_or_system_admin: Mount.is_lms_or_system_admin?(user, section),
           breadcrumbs: set_breadcrumbs(type, section),
           instructors: fetch_instructors(section),
           user: user,
           section: section,
           updates_count: updates_count,
           submission_count:
             Oli.Delivery.Attempts.ManualGrading.count_submitted_attempts(section),
           collab_space_config: collab_space_config,
           resource_slug: revision_slug,
           show_required_section_config: show_required_section_config
         )}
    end
  end

  defp fetch_instructors(section) do
    Sections.browse_enrollments(
      section,
      %Paging{offset: 0, limit: 50},
      %Sorting{direction: :asc, field: :name},
      %EnrollmentBrowseOptions{
        is_student: false,
        is_instructor: true,
        text_search: nil
      }
    )
  end

  def render(assigns) do
    deployment = assigns.section.lti_1p3_deployment

    ~F"""
    {render_modal(assigns)}
    <Groups>
      <Group label="Details" description="Overview of course section details">
        <ReadOnly label="Course Section ID" value={@section.slug}/>
        <ReadOnly label="Title" value={@section.title}/>
        <ReadOnly label="Course Section Type" value={type_to_string(@section)}/>
        <ReadOnly label="URL" value={Routes.page_delivery_url(OliWeb.Endpoint, :index, @section.slug)}/>
        {#unless is_nil(deployment)}
          <ReadOnly
            label="Institution"
            type={if @is_system_admin, do: "link"}
            link_label={deployment.institution.name}
            value={if @is_system_admin,
              do: Routes.institution_path(OliWeb.Endpoint, :show, deployment.institution_id),
              else: deployment.institution.name}
          />
        {/unless}
      </Group>
      <Group label="Instructors" description="Manage users with instructor level access">
        <Instructors users={@instructors}/>
      </Group>
      <Group label="Curriculum" description="Manage content delivered to students">
        <ul class="link-list">
        <li>
          <a target="_blank" href={Routes.instructor_dashboard_path(OliWeb.Endpoint, :preview, @section.slug, :content)} class={"btn btn-link"}><span>Preview Course as Instructor</span> <i class="fas fa-external-link-alt self-center ml-1"></i></a>
        </li>
        <li><a href={Routes.page_delivery_path(OliWeb.Endpoint, :index, @section.slug)} class={"btn btn-link"} target="_blank"><span>Enter Course as a Student</span> <i class="fas fa-external-link-alt self-center ml-1"></i></a></li>
        <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, @section.slug)} class={"btn btn-link"}>Customize Curriculum</a></li>
        <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.ScheduleView , @section.slug)} class={"btn btn-link"}>Scheduling</a></li>
        <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling, @section.slug)} class={"btn btn-link"}>Advanced Gating and Scheduling</a></li>
          <li>
            <a disabled={@updates_count == 0} href={Routes.source_materials_path(OliWeb.Endpoint, OliWeb.Delivery.ManageSourceMaterials, @section.slug)} class={"btn btn-link"}>
              Manage Source Materials
              {#if @updates_count > 0}
                <span class="badge badge-primary">{@updates_count} available</span>
              {/if}
            </a>
          </li>
        </ul>
      </Group>
      <Group label="Manage" description="Manage all aspects of course delivery">
        <ul class="link-list">
          <li><a
              href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EnrollmentsView, @section.slug)}
              class="btn btn-link"
            >Manage Enrolled Students</a></li>
          {#if @section.open_and_free}
            <li><a
                href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.InviteView, @section.slug)}
                class="btn btn-link"
              >Invite Students</a></li>
          {/if}
          <li><a
              href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EditView, @section.slug)}
              class="btn btn-link"
            >Edit Section Details</a></li>
          <li><a
              href={Routes.collab_spaces_index_path(OliWeb.Endpoint, :instructor, @section.slug)}
              class="btn btn-link"
            >Browse Collaborative Spaces</a></li>
          <li><button
              type="button"
              class="btn btn-link text-danger action-button"
              :on-click="show_delete_modal"
            >Delete Section</button></li>
        </ul>
      </Group>
      <Group
        label="Required Survey"
        description="Show a required to students who access the course for the first time"
      >
        {#if @show_required_section_config}
          {live_component(RequiredSurvey, %{
            project: @section,
            enabled: @section.required_survey_resource_id,
            is_section: true,
            id: "section-required-survey-section"
          })}
        {#else}
          <div class="flex items-center h-full ml-8">
            <p class="m-0">You are not allowed to have student surveys in this resource.<br>Please contact the admin to be granted with that permission.</p>
          </div>
        {/if}
      </Group>
      <Group label="Collaborative Space" description="Activate and configure a collaborative space for this section">
        <div class="container mx-auto">
          {#if @collab_space_config && @collab_space_config.status != :disabled}
            {live_render(@socket, OliWeb.CollaborationLive.CollabSpaceConfigView,
              id: "collab_space_config",
              session: %{
                "collab_space_config" => @collab_space_config,
                "section_slug" => @section.slug,
                "resource_slug" => @resource_slug,
                "is_overview_render" => true,
                "is_delivery" => true
              }
            )}
          {#else}
            <p class="ml-8 mt-2">Collaborative spaces are not enabled by the course project.<br>Please contact a system administrator to enable.</p>
          {/if}
        </div>
      </Group>
      <Group label="Grading" description="View and manage student grades and progress">
        <ul class="link-list">
          <li><a
              href={Routes.live_path(OliWeb.Endpoint, OliWeb.ManualGrading.ManualGradingView, @section.slug)}
              class="btn btn-link"
            >
              Score Manually Graded Activities
              {#if @submission_count > 0}
                <span class="badge badge-primary">{@submission_count}</span>
              {/if}
            </a>
          </li>
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradebookView, @section.slug)} class={"btn btn-link"}>View all Grades</a></li>
          <li><a href={Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, @section.slug)} class={"btn btn-link"}>Download Gradebook as <code>.csv</code> file</a></li>

          {#if @is_system_admin}
            <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Snapshots.SnapshotsView, @section.slug)} class={"btn btn-link"}>Manage Snapshot Records</a></li>
          {/if}
          {#if !@section.open_and_free}
            <li><a
                href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradesLive, @section.slug)}
                class="btn btn-link"
              >Manage LMS Gradebook</a></li>
            <li><a
                href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.FailedGradeSyncLive, @section.slug)}
                class="btn btn-link"
              >View Grades that failed to sync</a></li>
            {#if @is_lms_or_system_admin}
              <li><a
                  href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.ObserveGradeUpdatesView, @section.slug)}
                  class="btn btn-link"
                >Observe grade updates in real-time</a></li>
            {/if}
            <li><a
                href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.BrowseUpdatesView, @section.slug)}
                class="btn btn-link"
              >Browse LMS Grade Update Log</a></li>
          {/if}
        </ul>
      </Group>

      {#if @is_lms_or_system_admin and !@section.open_and_free}
        <Group label="LMS Admin" description="Administrator LMS Connection">
          <UnlinkSection unlink="unlink" section={@section} />
        </Group>
      {/if}
    </Groups>
    """
  end

  defp type_to_string(section) do
    case section.open_and_free do
      true -> "Direct Delivery"
      _ -> "LTI"
    end
  end

  def handle_event("unlink", _, socket) do
    %{section: section} = socket.assigns

    {:ok, _deleted} = Oli.Delivery.Sections.soft_delete_section(section)

    {:noreply, push_redirect(socket, to: Routes.delivery_path(socket, :index))}
  end

  def handle_event("show_delete_modal", _params, socket) do
    section_has_student_data = Sections.has_student_data?(socket.assigns.section.slug)

    {message, action} =
      if section_has_student_data do
        {"""
           This section has student data and will be archived rather than deleted.
           Are you sure you want to archive it? You will no longer have access to the data. Archiving this section will make it so students can no longer access it.
         """, "Archive"}
      else
        {"""
           This action cannot be undone. Are you sure you want to delete this section?
         """, "Delete"}
      end

    modal_assigns = %{
      id: "delete_section_modal",
      description: message,
      entity_type: "section",
      entity_id: socket.assigns.section.id,
      delete_enabled: true,
      delete: "delete_section",
      modal_action: action
    }

    modal = fn assigns ->
      ~F"""
      <DeleteModalNoConfirmation {...@modal_assigns} />
      """
    end

    {:noreply,
     show_modal(socket, modal,
       modal_assigns: modal_assigns,
       section_has_student_data: section_has_student_data
     )}
  end

  def handle_event("delete_section", _, socket) do
    socket = clear_flash(socket)

    socket =
      if socket.assigns.section_has_student_data ==
           Sections.has_student_data?(socket.assigns.section.slug) do
        {action_function, action} =
          if socket.assigns.section_has_student_data do
            {&Sections.update_section(&1, %{status: :archived}), "archived"}
          else
            {&Sections.delete_section/1, "deleted"}
          end

        case action_function.(socket.assigns.section) do
          {:ok, _section} ->
            is_admin = socket.assigns.is_system_admin

            redirect_path =
              if is_admin do
                Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.SectionsView)
              else
                Routes.delivery_path(socket.endpoint, :open_and_free_index)
              end

            socket
            |> put_flash(:info, "Section successfully #{action}.")
            |> redirect(to: redirect_path)

          {:error, %Ecto.Changeset{}} ->
            put_flash(
              socket,
              :error,
              "Section couldn't be #{action}."
            )
        end
      else
        put_flash(
          socket,
          :error,
          "Section had student activity recently. It can now only be archived, please try again."
        )
      end

    {:noreply, socket |> hide_modal(modal_assigns: nil, section_has_student_data: nil)}
  end
end
