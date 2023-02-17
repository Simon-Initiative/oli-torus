defmodule OliWeb.Sections.ScheduleView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.{Breadcrumb, Confirm, SessionContext}

  data breadcrumbs, :any
  data title, :string, default: "Schedule Section"
  data section, :any, default: nil
  data show_confirm, :boolean, default: false
  data to_delete, :integer, default: nil

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

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        {:ok,
         assign(socket,
           context: SessionContext.init(session),
           delivery_breadcrumb: true,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           js_path: Routes.static_path(OliWeb.Endpoint, "/js/scheduler.js"),
           appConfig: %{
             start_date: section.start_date,
             end_date: section.end_date,
             title: section.title,
             section_slug: section_slug,
             display_curriculum_item_numbering: section.display_curriculum_item_numbering
           }
         )}
    end
  end

  def render(assigns) do
    ~H"""

    <script type="text/javascript" src={ @js_path }></script>

    <div id="app" phx-update="ignore">
      <%= ReactPhoenix.ClientSide.react_component("Components.ScheduleEditor", @appConfig) %>
    </div>
    """
  end
end
