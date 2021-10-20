defmodule OliWeb.Sections.OverviewView do
  use Surface.LiveView
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb}
  alias OliWeb.Common.Properties.{Groups, Group, ReadOnly}
  alias Oli.Accounts.Author
  alias Oli.Delivery.Sections.{EnrollmentBrowseOptions}
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections
  alias OliWeb.Sections.{Instructors}

  prop author, :any
  data breadcrumbs, :any
  data title, :string, default: "Section Details"
  data section, :any, default: nil
  data instructors, :list, default: []
  data is_admin, :boolean
  data updates_count, :integer

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "All Course Sections",
          link: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.SectionsView)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)

    case Sections.get_section_by(slug: section_slug) do
      nil ->
        {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :not_found))}

      section ->
        updates_count =
          Sections.check_for_available_publication_updates(section)
          |> Enum.count()

        {:ok,
         assign(socket,
           is_admin: Oli.Accounts.is_admin?(author),
           breadcrumbs: set_breadcrumbs(),
           instructors: fetch_instructors(section),
           author: author,
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
        <ReadOnly label="Title" value={@section.title}/>
        <ReadOnly label="Course Section Type" value={type_to_string(@section)}/>
      </Group>
      <Group label="Instructors" description="Manage the users with instructor level access">
        <Instructors users={@instructors}/>
      </Group>
      <Group label="Curriculum" description="Manage the content delivered to students">
        <ul class="link-list">
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, @section.slug)}>Customize Curriculum</a></li>
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
      <Group label="Manage" description="Manage all aspects of course delivery including enrollments and grades">
        <ul class="link-list">
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EnrollmentsView, @section.slug)}>View Enrolled Students</a></li>
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EditView, @section.slug)}>Edit Section Details</a></li>
        </ul>
      </Group>
      {#if !@section.open_and_free}
        <Group label="LMS" description="Manage LMS Connection">
          <ul class="link-list">
            <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradesLive, @section.slug)}>Manage LMS Gradebook</a></li>
          </ul>
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
end
