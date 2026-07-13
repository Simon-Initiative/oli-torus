defmodule OliWeb.Sections.AssessmentSettings.SettingsLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Settings.AssessmentSettings
  alias OliWeb.Icons
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount

  @scoring_mode_warning_dismissed_preference :assessment_settings_scoring_mode_warning_dismissed

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
           show_scoring_mode_warning: show_scoring_mode_warning?(user),
           students:
             Sections.enrolled_students(section.slug)
             |> Enum.reject(fn s -> s.user_role_id != 4 end)
             |> Enum.sort(),
           assessments: AssessmentSettings.get_assessments(section, student_exceptions),
           user_type: user_type
         )}
    end
  end

  defp set_breadcrumbs(_type, %{type: :blueprint} = section, socket) do
    route_name = socket.assigns[:route_name]
    project = socket.assigns[:project]
    product_path_base = product_path_base(section, socket)

    [
      Breadcrumb.new(%{
        full_title: "Template Overview",
        link: Breadcrumb.product_overview_link(section, route_name, project)
      }),
      Breadcrumb.new(%{
        full_title: "Assessment Settings",
        link: "#{product_path_base}/assessment_settings/settings/all"
      })
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
        return_to: current_path(url),
        update_sort_order: true,
        product_path_base: product_path_base(socket.assigns.section, socket),
        breadcrumbs: set_breadcrumbs(socket.assigns.user_type, socket.assigns.section, socket)
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
        <.scoring_mode_warning_banner :if={@show_scoring_mode_warning} />
        <.live_component
          id="assessment_settings_table"
          module={OliWeb.Sections.AssessmentSettings.SettingsTable}
          assessments={@assessments}
          params={@params}
          section={@section}
          user={@user}
          ctx={@ctx}
          update_sort_order={@update_sort_order}
          product_path_base={@product_path_base}
          return_to={@return_to}
        />
      </div>
    </div>
    """
  end

  defp scoring_mode_warning_banner(assigns) do
    ~H"""
    <div
      id="assessment-settings-scoring-mode-warning"
      class="mb-5 rounded-lg bg-Fill-Accent-fill-accent-orange px-5 py-4"
      role="region"
      aria-labelledby="assessment-settings-scoring-mode-warning-region-label"
      aria-describedby="assessment-settings-scoring-mode-warning-message"
    >
      <span id="assessment-settings-scoring-mode-warning-region-label" class="sr-only">
        Scoring mode warning
      </span>
      <div class="flex items-start justify-between gap-5">
        <div class="min-w-0 flex-1">
          <div class="flex items-start gap-2">
            <Icons.warning_triangle class="h-4 w-4 shrink-0 stroke-Icon-icon-accent-orange" />
            <div
              id="assessment-settings-scoring-mode-warning-title"
              class="text-base font-semibold leading-4 text-Text-text-high"
            >
              Important
            </div>
          </div>
          <p class="m-0 mt-2 text-base font-semibold leading-6 text-Text-text-high">
            <span id="assessment-settings-scoring-mode-warning-message">
              Review scoring mode settings before students begin work. Once students start an assignment, the scoring mode is locked to preserve the student experience.
            </span>
            <button
              type="button"
              class="inline p-0 text-base font-semibold leading-6 text-Text-text-link underline hover:text-Text-text-link-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Text-text-link"
              phx-click="dismiss_scoring_mode_warning_permanently"
            >
              Don&apos;t show me this again
            </button>
          </p>
        </div>
        <button
          type="button"
          class="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-lg p-2 text-Icon-icon-accent-orange shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] hover:text-Icon-icon-accent-orange-bold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Text-text-link"
          aria-label="Dismiss scoring mode warning"
          phx-click="dismiss_scoring_mode_warning"
        >
          <Icons.close_sm class="h-4 w-4 stroke-current" />
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("dismiss_scoring_mode_warning", _params, socket) do
    {:noreply, assign(socket, show_scoring_mode_warning: false)}
  end

  @impl true
  def handle_event("dismiss_scoring_mode_warning_permanently", _params, socket) do
    case dismiss_scoring_mode_warning(socket.assigns.user) do
      {:ok, _} ->
        {:noreply, assign(socket, show_scoring_mode_warning: false)}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Could not dismiss scoring mode warning. Please try again.")}
    end
  end

  defp current_path(url) do
    %{path: path, query: query} = URI.parse(url)

    case query do
      nil -> path
      "" -> path
      query -> "#{path}?#{query}"
    end
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
         %{type: :blueprint} = section,
         %{assigns: %{route_name: :workspaces}} = socket
       ) do
    Breadcrumb.product_path_base(section, :workspaces, socket.assigns.project)
  end

  defp product_path_base(%{type: :blueprint, slug: section_slug}, _socket),
    do: ~p"/authoring/products/#{section_slug}"

  defp product_path_base(_, _), do: nil

  defp show_scoring_mode_warning?(account) do
    !scoring_mode_warning_dismissed?(account)
  end

  defp scoring_mode_warning_dismissed?(%User{} = user) do
    Accounts.get_user_preference(user, @scoring_mode_warning_dismissed_preference, false)
  end

  defp scoring_mode_warning_dismissed?(%Author{} = author) do
    Accounts.get_author_preference(author, @scoring_mode_warning_dismissed_preference, false)
  end

  defp dismiss_scoring_mode_warning(%User{} = user) do
    Accounts.set_user_preference(user, @scoring_mode_warning_dismissed_preference, true)
  end

  defp dismiss_scoring_mode_warning(%Author{} = author) do
    Accounts.set_author_preference(author, @scoring_mode_warning_dismissed_preference, true)
  end
end
