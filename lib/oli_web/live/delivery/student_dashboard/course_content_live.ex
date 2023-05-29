defmodule OliWeb.Delivery.StudentDashboard.CourseContentLive do
  use OliWeb, :live_view

  alias Oli.Delivery.Sections

  @impl Phoenix.LiveView
  def mount(
        _params,
        %{"section_slug" => section_slug, "current_user_id" => current_user_id} = _session,
        socket
      ) do
    section =
      Sections.get_section_by_slug(section_slug)
      |> Oli.Repo.preload([:base_project, :root_section_resource])

    hierarchy = %{"children" => Sections.build_hierarchy(section).children}
    current_position = 0
    current_level = 0

    {:ok,
     assign(socket,
       hierarchy: hierarchy,
       current_level_nodes: hierarchy["children"],
       current_position: current_position,
       current_level: current_level,
       scheduled_dates:
         Sections.get_resources_scheduled_dates_for_student(section.slug, current_user_id),
       section: section,
       breadcrumbs_tree: [{current_level, current_position, "Curriculum"}],
       current_user_id: current_user_id
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <.live_component
        module={OliWeb.Delivery.CourseContent}
        id="course_content_tab"
        hierarchy={assigns.hierarchy}
        current_position={assigns.current_position}
        current_level={assigns.current_level}
        current_level_nodes={assigns.current_level_nodes}
        breadcrumbs_tree={assigns.breadcrumbs_tree}
        section={assigns.section}
        scheduled_dates={assigns.scheduled_dates}
        current_user_id={assigns.current_user_id}
      />
    """
  end
end
