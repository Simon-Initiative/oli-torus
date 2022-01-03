defmodule OliWeb.Sections.OverviewView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb}
  alias OliWeb.Common.Properties.{Groups, Group, ReadOnly}
  alias Oli.Delivery.Sections.{EnrollmentBrowseOptions}
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections
  alias OliWeb.Sections.{Instructors, UnlinkSection}
  alias OliWeb.Sections.Mount

  prop user, :any
  data breadcrumbs, :any
  data title, :string, default: "Section Details"
  data section, :any, default: nil
  data instructors, :list, default: []
  data updates_count, :integer

  def set_breadcrumbs(:admin, section) do
    OliWeb.Sections.SectionsView.set_breadcrumbs()
    |> breadcrumb(section)
  end

  def set_breadcrumbs(:user, section) do
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
           updates_count: updates_count
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
    <Groups>
      <Group label="Overview" description="Overview of this course section">
        <ReadOnly label="Course Section ID" value={@section.slug}/>
        <ReadOnly label="Title" value={@section.title}/>
        <ReadOnly label="Course Section Type" value={type_to_string(@section)}/>
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
            <a disabled={@updates_count == 0} href={Routes.page_delivery_path(OliWeb.Endpoint, :updates, @section.slug)}>
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
        </ul>
      </Group>
      <Group label="Grading" description="View and manage student grades and progress">
        <ul class="link-list">
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradebookView, @section.slug)}>View Grades</a></li>
          <li><a href={Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, @section.slug)}>Download Gradebook as <code>.csv</code> file</a></li>
          {#if !@section.open_and_free}
            <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradesLive, @section.slug)}>Manage LMS Gradebook</a></li>
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
      true -> "LMS-Lite"
      _ -> "LTI"
    end
  end

  def handle_event("unlink", _, socket) do
    %{section: section} = socket.assigns

    {:ok, _deleted} = Oli.Delivery.Sections.soft_delete_section(section)

    {:noreply, push_redirect(socket, to: Routes.delivery_path(socket, :index))}
  end
end
