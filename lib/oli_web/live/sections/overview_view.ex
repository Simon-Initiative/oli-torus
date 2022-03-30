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

  prop user, :any
  data breadcrumbs, :any
  data title, :string, default: "Section Details"
  data section, :any, default: nil
  data instructors, :list, default: []
  data updates_count, :integer
  data submission_count, :integer
  data section_has_student_data, :boolean

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
          full_title: "Section Overview",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, user, section} ->
        updates_count =
          Sections.check_for_available_publication_updates(section)
          |> Enum.count()

        {:ok,
         assign(socket,
           is_admin: Mount.is_lms_or_system_admin?(user, section),
           breadcrumbs: set_breadcrumbs(type, section),
           instructors: fetch_instructors(section),
           user: user,
           section: section,
           updates_count: updates_count,
           submission_count: Oli.Delivery.Attempts.ManualGrading.count_submitted_attempts(section)
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
    ~F"""
    {render_modal(assigns)}
    <Groups>
      <Group label="Overview" description="Overview of this course section">
        <ReadOnly label="Course Section ID" value={@section.slug}/>
        <ReadOnly label="Title" value={@section.title}/>
        <ReadOnly label="Course Section Type" value={type_to_string(@section)}/>
        <ReadOnly label="URL" value={Routes.page_delivery_url(OliWeb.Endpoint, :index, @section.slug)}/>
      </Group>
      <Group label="Instructors" description="Manage the users with instructor level access">
        <Instructors users={@instructors}/>
      </Group>
      <Group label="Curriculum" description="Manage the content delivered to students">
        <ul class="link-list">
        <li><a href={Routes.page_delivery_path(OliWeb.Endpoint, :index_preview, @section.slug)}>Preview Course Content</a></li>
        <li><a href={Routes.page_delivery_path(OliWeb.Endpoint, :index, @section.slug)}>Enter Course as a Student</a></li>
        <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, @section.slug)}>Customize Curriculum</a></li>
        <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling, @section.slug)}>Gating and Scheduling</a></li>
          <li>
            <a disabled={@updates_count == 0} href={Routes.section_updates_path(OliWeb.Endpoint, OliWeb.Delivery.ManageUpdates, @section.slug)}>
              Manage Updates
              {#if @updates_count > 0}
                <span class="badge badge-primary">{@updates_count} available</span>
              {/if}
            </a>
          </li>
        </ul>
      </Group>
      <Group label="Manage" description="Manage all aspects of course delivery">
        <ul class="link-list">
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EnrollmentsView, @section.slug)}>Manage Enrolled Students</a></li>
          {#if @section.open_and_free}
            <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.InviteView, @section.slug)}>Invite Students</a></li>
          {/if}
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EditView, @section.slug)}>Edit Section Details</a></li>
          <li>
            <button type="button" class="p-0 btn btn-link text-danger action-button" :on-click="show_delete_modal">Delete Section</button>
          </li>
        </ul>
      </Group>
      <Group label="Grading" description="View and manage student grades and progress">
        <ul class="link-list">
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.ManualGrading.ManualGradingView, @section.slug)}>
            Score Manually Graded Activities
            {#if @submission_count > 0}
                <span class="badge badge-primary">{@submission_count}</span>
              {/if}
            </a>
          </li>
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradebookView, @section.slug)}>View Grades</a></li>
          <li><a href={Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, @section.slug)}>Download Gradebook as <code>.csv</code> file</a></li>
          {#if !@section.open_and_free}
            <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradesLive, @section.slug)}>Manage LMS Gradebook</a></li>
            {#if @is_admin}
              <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.ObserveGradeUpdatesView, @section.slug)}>Observe grade updates in real-time</a></li>
            {/if}
            <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.BrowseUpdatesView, @section.slug)}>Browse LMS Grade Update Log</a></li>
          {/if}
          </ul>
      </Group>

      {#if @is_admin and !@section.open_and_free}
        <Group label="LMS Admin" description="Administrator LMS Connection">
          <UnlinkSection unlink="unlink" section={@section}/>
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

    modal = %{
      component: DeleteModalNoConfirmation,
      assigns: %{
        id: "delete_section_modal",
        description: message,
        entity_type: "section",
        entity_id: socket.assigns.section.id,
        delete_enabled: true,
        delete: "delete_section",
        modal_action: action
      }
    }

    {:noreply, assign(socket, modal: modal, section_has_student_data: section_has_student_data)}
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
            socket
            |> put_flash(:info, "Section successfully #{action}.")
            |> redirect(to: Routes.delivery_path(socket.endpoint, :open_and_free_index))

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

    {:noreply, socket |> hide_modal()}
  end
end
