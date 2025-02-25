defmodule OliWeb.Sections.ScheduleView do
  use OliWeb, :live_view

  alias Oli.Delivery.Sections
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.{Breadcrumb}
  alias OliWeb.Workspaces.CourseAuthor.Products

  defp set_breadcrumbs(:product, project_slug, product) do
    Products.Breadcrumbs.product_overview(project_slug, product.slug)
    ++ [
      Breadcrumb.new(%{
        full_title: "Schedule",
        link: ~p"/workspaces/course_author/#{project_slug}/products/#{product.slug}/schedule"
      })
    ]
  end

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

  def mount(%{"project_id" => project_slug, "product_id" => product_slug}, _session, %{assigns: %{live_action: :product}} = socket) do
    product = Sections.get_section_by_slug(product_slug)

    {:ok,
      assign(socket,
        breadcrumbs: set_breadcrumbs(:product, project_slug, product),
        section: product,
        js_path: Routes.static_path(OliWeb.Endpoint, "/js/scheduler.js"),
        appConfig: %{
          start_date: product.start_date,
          end_date: product.end_date,
          preferred_scheduling_time: product.preferred_scheduling_time,
          title: product.title,
          section_slug: product.slug,
          display_curriculum_item_numbering: product.display_curriculum_item_numbering,
          edit_section_details_url:
            Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EditView, product.slug)
        }
      )}
  end

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
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
               Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EditView, section.slug)
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

    <div id="schedule-app" phx-update="ignore">
      <%= ReactPhoenix.ClientSide.react_component("Components.ScheduleEditor", @appConfig) %>
    </div>
    """
  end
end
