defmodule OliWeb.Sections.AssessmentSettings.SettingsLive do
  use Phoenix.LiveView

  import Ecto.Query
  alias Oli.Repo

  alias OliWeb.Sections.Mount
  alias OliWeb.Common.SessionContext
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Settings
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Settings.StudentException
  alias OliWeb.Sections.AssessmentSettings.AssessmentSetting

  @impl true
  def mount(%{"section_slug" => section_slug} = params, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, error} ->
        {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, error))}

      {_user_type, current_user, section} ->
        section =
          section
          |> Oli.Repo.preload([:base_project, :root_section_resource])

        student_exceptions = get_student_exceptions(section.id)

        {:ok,
         assign(socket,
           context: SessionContext.init(session),
           current_user: current_user,
           preview_mode: socket.assigns[:live_action] == :preview,
           section: section,
           student_exceptions: student_exceptions,
           assessments: get_assessments(section.slug, student_exceptions)
         )}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"active_tab" => "settings"} = params, _, socket) do
    socket =
      socket
      |> assign(
        params: params,
        active_tab: :settings
      )

    {:noreply, socket}
  end

  @impl true
  def handle_params(%{"active_tab" => "student_exceptions"} = params, _, socket) do
    socket =
      socket
      |> assign(
        params: params,
        active_tab: :student_exceptions
      )

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
      <div class="container mx-auto my-4">
        <ul class="nav nav-tabs flex flex-col md:flex-row flex-wrap list-none border-b-0 pl-0 mb-4" id="tabs-tab"
          role="tablist">

          <%= for {label, tab_name, active} <- [
            {"Assessment Settings", :settings, is_active_tab?(:settings, @active_tab)},
            {"Student Exceptions", :student_exceptions, is_active_tab?(:student_exceptions, @active_tab)},
          ] do %>
            <li class="nav-item" role="presentation">
              <a
              phx-click="change_tab"
              phx-value-selected_tab={tab_name}
                class={"
                  block
                  border-x-0 border-t-0 border-b-2
                  px-1
                  py-3
                  m-2
                  text-body-color
                  dark:text-body-color-dark
                  bg-transparent
                  hover:no-underline
                  hover:text-body-color
                  hover:border-delivery-primary-200
                  focus:border-delivery-primary-200
                  #{if active, do: "border-delivery-primary", else: "border-transparent"}
                "}>
                  <%= label %>
              </a>
            </li>
          <% end %>
        </ul>
        <%= if @active_tab == :settings do %>
          <.live_component
            id="assessment_settings_table"
            module={OliWeb.Sections.AssessmentSettings.SettingsTable}
            assessments={@assessments}
            params={@params}
            section_slug={@section.slug}
          />
        <% else %>
        <.live_component
            id="student_exeptions_table"
            module={OliWeb.Sections.AssessmentSettings.StudentExceptionsTable}
            student_exceptions={@student_exceptions}
            assessments={@assessments}
            params={@params}
            section_slug={@section.slug}
          />
        <% end %>
      </div>
    """
  end

  @impl true
  def handle_event("change_tab", %{"selected_tab" => selected_tab}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           socket.assigns.section.slug,
           selected_tab,
           :all
         )
     )}
  end

  defp is_active_tab?(tab, active_tab), do: tab == active_tab

  defp get_assessments(section_slug, student_exceptions) do
    DeliveryResolver.graded_pages_revisions_and_section_resources(section_slug)
    |> Enum.map(fn {rev, sr} ->
      Settings.combine(rev, sr, nil)
      |> Map.merge(%{
        name: rev.title,
        exceptions_count:
          Enum.count(student_exceptions, fn se -> se.resource_id == rev.resource_id end)
      })
    end)
  end

  defp get_student_exceptions(section_id) do
    StudentException
    |> where(section_id: ^section_id)
    |> preload(:user)
    |> Repo.all()
  end
end
