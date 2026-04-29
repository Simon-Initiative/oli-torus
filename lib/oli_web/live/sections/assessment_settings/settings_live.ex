defmodule OliWeb.Sections.AssessmentSettings.SettingsLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Settings.AssessmentSettings
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount

  on_mount OliWeb.LiveSessionPlugs.SetRouteName

  @impl true
  def mount(%{"section_slug" => section_slug} = _params, _session, socket) do
    case Mount.for(section_slug, socket) do
      {:error, error} ->
        {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, error))}

      {user_type, user, section} ->
        section =
          section
          |> Oli.Repo.preload([:base_project, :root_section_resource])

        student_exceptions = AssessmentSettings.get_student_exceptions(section.id)

        {:ok,
         assign(socket,
           preview_mode: socket.assigns[:live_action] == :preview,
           title: "Assessment Settings",
           section: section,
           user: user,
           student_exceptions: student_exceptions,
           students:
             Sections.enrolled_students(section.slug)
             |> Enum.reject(fn s -> s.user_role_id != 4 end)
             |> Enum.sort(),
           assessments: AssessmentSettings.get_assessments(section, student_exceptions),
           breadcrumbs: set_breadcrumbs(user_type, section)
         )}
    end
  end

  defp set_breadcrumbs(_type, %{type: :blueprint} = section) do
    [
      Breadcrumb.new(%{
        full_title: "Template Overview",
        link: Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, section.slug)
      }),
      Breadcrumb.new(%{
        full_title: "Assessment Settings",
        link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug, "all")
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
          full_title: "Assessments settings",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug, "all")
        })
      ]
  end

  @impl Phoenix.LiveView
  def handle_params(params, url, socket) do
    socket =
      assign(socket,
        params: params,
        uri: URI.parse(url).path,
        update_sort_order: true,
        product_path_base: product_path_base(socket.assigns.section, socket)
      )

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto">
      <OliWeb.Components.Delivery.ScheduleGatingAssessment.tabs
        :if={@section.type == :blueprint}
        section_slug={@section.slug}
        uri={@uri}
        product_path_base={@product_path_base}
      />
      <div class="mb-5">
        <.live_component
          id="assessment_settings_table"
          module={OliWeb.Sections.AssessmentSettings.SettingsTable}
          assessments={@assessments}
          params={@params}
          section={@section}
          user={@user}
          ctx={@ctx}
          update_sort_order={@update_sort_order}
        />
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({:flash_message, type, message}, socket) do
    {:noreply, socket |> clear_flash |> put_flash(type, message)}
  end

  @impl true
  def handle_info({:assessment_updated, updated_assessment, update_sort_order}, socket) do
    updated_assessments =
      socket.assigns.assessments
      |> Enum.into([], fn assessment ->
        if assessment.resource_id == updated_assessment.resource_id,
          do: updated_assessment,
          else: assessment
      end)

    sr =
      Oli.Delivery.Sections.get_section_resource(
        socket.assigns.section.id,
        updated_assessment.resource_id
      )

    Oli.Delivery.DepotCoordinator.update_all(
      Oli.Delivery.Sections.SectionResourceDepot.depot_desc(),
      [sr]
    )

    {:noreply,
     socket
     |> assign(
       assessments: updated_assessments,
       update_sort_order: update_sort_order
     )}
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
