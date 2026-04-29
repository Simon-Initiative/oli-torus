defmodule OliWeb.Sections.ScheduleView do
  use OliWeb, :live_view

  alias Oli.Authoring.Course.Project
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.{Breadcrumb, React}

  on_mount OliWeb.LiveSessionPlugs.SetRouteName

  defp set_breadcrumbs(_type, %{type: :blueprint} = section, socket) do
    route_name = socket.assigns[:route_name]
    project = socket.assigns[:project]

    overview_link = Breadcrumb.product_overview_link(section, route_name, project)

    page_link =
      case {route_name, project} do
        {:workspaces, %Project{slug: project_slug}} ->
          ~p"/workspaces/course_author/#{project_slug}/products/#{section.slug}/schedule"

        _ ->
          ~p"/authoring/products/#{section.slug}/schedule"
      end

    [
      Breadcrumb.new(%{full_title: "Template Overview", link: overview_link}),
      Breadcrumb.new(%{full_title: "Schedule", link: page_link})
    ]
  end

  defp set_breadcrumbs(type, section, _socket) do
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

      {user_type, _user, section} ->
        {:ok, assign(socket, user_type: user_type, section: section)}
    end
  end

  def handle_params(_params, url, socket) do
    section = socket.assigns.section
    type = socket.assigns.user_type

    edit_url =
      case {section.type, Map.get(socket.assigns, :route_name)} do
        {:blueprint, :workspaces} ->
          %Project{slug: project_slug} = socket.assigns.project
          ~p"/workspaces/course_author/#{project_slug}/products/#{section.slug}/edit"

        {:blueprint, _} ->
          ~p"/authoring/products/#{section.slug}/edit"

        _ ->
          Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EditView, section.slug)
      end

    {:noreply,
     assign(socket,
       breadcrumbs: set_breadcrumbs(type, section, socket),
       uri: URI.parse(url).path,
       product_path_base: product_path_base(section, socket),
       appConfig: %{
         start_date: section.start_date,
         end_date: section.end_date,
         preferred_scheduling_time: section.preferred_scheduling_time,
         title: section.title,
         section_slug: section.slug,
         display_curriculum_item_numbering: section.display_curriculum_item_numbering,
         edit_section_details_url: edit_url,
         is_blueprint: section.type == :blueprint,
         agenda: section.agenda
       }
     )}
  end

  attr(:breadcrumbs, :any)
  attr(:title, :string, default: "Schedule Section")
  attr(:section, :any, default: nil)
  attr(:show_confirm, :boolean, default: false)
  attr(:to_delete, :integer, default: nil)

  def render(assigns) do
    ~H"""
    <Components.Delivery.ScheduleGatingAssessment.tabs
      :if={@section.type == :blueprint}
      section_slug={@section.slug}
      uri={@uri}
      product_path_base={@product_path_base}
    />
    {React.component(@ctx, "Components.ScheduleEditor", @appConfig, id: "schedule-editor")}
    """
  end

  defp product_path_base(
         %{type: :blueprint, slug: section_slug},
         %{assigns: %{route_name: :workspaces}} = socket
       ) do
    %Project{slug: project_slug} = socket.assigns.project
    ~p"/workspaces/course_author/#{project_slug}/products/#{section_slug}"
  end

  defp product_path_base(%{type: :blueprint, slug: section_slug}, _socket),
    do: ~p"/authoring/products/#{section_slug}"

  defp product_path_base(_, _), do: nil
end
