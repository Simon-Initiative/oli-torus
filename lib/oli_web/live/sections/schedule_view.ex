defmodule OliWeb.Sections.ScheduleView do
  use OliWeb, :live_view

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.{Breadcrumb}

  defp set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Schedule",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, _session, socket) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _user, section} ->
        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           js_path: Routes.static_path(OliWeb.Endpoint, "/js/scheduler.js"),
           appConfig: %{
             start_date: section.start_date,
             end_date: section.end_date,
             preferred_scheduling_time: section.preferred_scheduling_time,
             title: section.title,
             section_slug: section_slug,
             display_curriculum_item_numbering: section.display_curriculum_item_numbering,
             edit_section_details_url:
               Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EditView, section.slug),
             agenda: section.agenda
           }
         )}
    end
  end

  attr(:breadcrumbs, :any)
  attr(:title, :string, default: "Schedule Section")
  attr(:section, :any, default: nil)
  attr(:show_confirm, :boolean, default: false)
  attr(:to_delete, :integer, default: nil)

  def render(assigns) do
    ~H"""
    <script type="text/javascript" src={@js_path} />

    <div
      id="schedule-container"
      phx-update="ignore"
    >
      <div id="schedule-app">
        <%= ReactPhoenix.ClientSide.react_component("Components.ScheduleEditor", @appConfig) %>
      </div>
    </div>
    """
  end
end
