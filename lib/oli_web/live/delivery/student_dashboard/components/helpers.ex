defmodule OliWeb.Delivery.StudentDashboard.Components.Helpers do
  use OliWeb, :html

  import OliWeb.ViewHelpers, only: [brand_logo: 1]

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Components.Delivery.UserAccount
  alias OliWeb.Components.Header
  alias OliWeb.Common.SessionContext

  attr(:ctx, SessionContext)
  attr(:student, User)
  attr(:section, Section)
  attr(:breadcrumbs, :list, required: true)
  attr(:socket_or_conn, :any, required: true)
  attr(:preview_mode, :boolean, default: false)
  slot(:inner_block, required: true)

  def main_layout(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col h-screen">
      <.header
        ctx={@ctx}
        student={@student}
        section={@section}
        preview_mode={@preview_mode}
        is_admin={@is_admin}
      />
      <Header.delivery_breadcrumb {assigns} />

      <div class="flex-1 flex flex-col">
        <div class="relative flex-1 flex flex-col pb-[60px]">
          <%= render_slot(@inner_block) %>
          <OliWeb.Components.Footer.delivery_footer license={
            Map.get(assigns, :has_license) && assigns[:license]
          } />
        </div>
      </div>
    </div>
    """
  end

  defp path_for(active_tab, section_slug, student_id, _preview_mode = true) do
    Routes.student_dashboard_path(
      OliWeb.Endpoint,
      :preview,
      section_slug,
      student_id,
      active_tab
    )
  end

  defp path_for(active_tab, section_slug, student_id, _preview_mode = false) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
      section_slug,
      student_id,
      active_tab
    )
  end

  attr(:active_tab, :atom,
    required: true,
    values: [
      :content,
      :learning_objectives,
      :quizz_scores,
      :progress
    ]
  )

  attr(:section_slug, :string, required: true)
  attr(:student_id, :string, required: true)
  attr(:preview_mode, :boolean, required: true)
  attr(:hidden_tabs, :list, default: [])

  def tabs(assigns) do
    ~H"""
    <div class="container mx-auto my-4">
      <ul
        class="nav nav-tabs flex flex-col md:flex-row flex-wrap list-none border-b-0 pl-0 mb-4"
        id="tabs-tab"
        role="tablist"
      >
        <%= for {label, href, badge, active, hidden} <- [
            {"Content", path_for(:content, @section_slug, @student_id, @preview_mode), nil, is_active_tab?(:content, @active_tab), is_hidden?(:content, @hidden_tabs)},
            {"Learning Objectives", path_for(:learning_objectives, @section_slug, @student_id, @preview_mode), nil, is_active_tab?(:learning_objectives, @active_tab), is_hidden?(:learning_objectives, @hidden_tabs)},
            {"Quiz Scores", path_for(:quizz_scores, @section_slug, @student_id, @preview_mode), nil, is_active_tab?(:quizz_scores, @active_tab), is_hidden?(:quizz_scores, @hidden_tabs)},
            {"Progress", path_for(:progress, @section_slug, @student_id, @preview_mode), nil, is_active_tab?(:progress, @active_tab), is_hidden?(:progress, @hidden_tabs)},
            {"Actions", path_for(:actions, @section_slug, @student_id, @preview_mode), nil, is_active_tab?(:actions, @active_tab), is_hidden?(:actions, @hidden_tabs)},
          ] do %>
          <%= if !hidden do %>
            <li class="nav-item" role="presentation">
              <.link
                patch={href}
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
                  "}
              >
                <%= label %>
                <%= if badge do %>
                  <span class="text-xs inline-block py-1 px-2 ml-2 leading-none text-center whitespace-nowrap align-baseline font-bold bg-delivery-primary text-white rounded">
                    <%= badge %>
                  </span>
                <% end %>
              </.link>
            </li>
          <% end %>
        <% end %>
      </ul>
    </div>
    """
  end

  defp is_active_tab?(tab, active_tab), do: tab == active_tab
  defp is_hidden?(tab, hidden_tabs), do: Enum.member?(hidden_tabs, tab)

  defp logo_link(nil, _, _),
    do: ~p"/workspaces/student"

  defp logo_link(section, student_id, preview_mode) do
    if preview_mode do
      Routes.student_dashboard_path(OliWeb.Endpoint, :preview, section.slug, student_id, :content)
    else
      ~p"/sections/#{section.slug}"
    end
  end

  attr(:ctx, SessionContext)
  attr(:student, User)
  attr(:section, Section)
  attr(:preview_mode, :boolean, default: false)
  attr(:is_admin, :boolean, required: true)

  def header(assigns) do
    ~H"""
    <div class="w-full bg-delivery-instructor-dashboard-header text-white border-b border-slate-600">
      <div class="container mx-auto py-2 flex flex-row justify-between">
        <div class="flex-1 flex items-center">
          <a
            class="navbar-brand dark torus-logo my-1 mr-auto"
            href={logo_link(@section, @student.id, @preview_mode)}
          >
            <%= brand_logo(Map.merge(assigns, %{class: "d-inline-block align-top mr-2"})) %>
          </a>
        </div>
        <%= if @preview_mode do %>
          <UserAccount.preview_user_menu ctx={@ctx} />
        <% else %>
          <UserAccount.menu id="user-account-menu" ctx={@ctx} is_admin={@is_admin} />
        <% end %>
        <div class="flex items-center border-l border-slate-300">
          <button
            aria-label="Request Help"
            class="
                btn
                rounded
                ml-4
                no-underline
                text-slate-100
                hover:no-underline
                hover:bg-delivery-instructor-dashboard-header-700
                active:bg-delivery-instructor-dashboard-header-600
              "
            onclick="window.showHelpModal();"
          >
            <i class="fa-regular fa-circle-question fa-lg"></i>
          </button>
        </div>
      </div>
    </div>
    """
  end

  defmodule SurveyResponse do
    use Ecto.Schema

    schema "survey_response" do
      field(:title, :string)
      field(:response, :string)
    end
  end

  attr(:student, User)
  attr(:survey_responses, :list)

  def student_details(assigns) do
    ~H"""
    <div id="student_details_card" class="flex flex-col sm:flex-row items-center mx-10">
      <div class="flex shrink-0 mb-6 sm:mb-0 sm:mr-6">
        <%= if @student.picture do %>
          <div class="text-center">
            <img src={@student.picture} class="rounded-full h-52 w-52" referrerPolicy="no-referrer" />
            <p class="text-gray-500 mt-2"><%= @student.email %></p>
          </div>
        <% else %>
          <div class="text-center">
            <i class="fa-solid fa-circle-user text-[208px] text-gray-200"></i>
            <p class="text-gray-500 mt-2"><%= @student.email %></p>
          </div>
        <% end %>
      </div>
      <div class="flex flex-col divide-y divide-gray-100 dark:divide-gray-700 w-full bg-white dark:bg-neutral-800">
        <div class="grid grid-cols-5 gap-4 w-full p-8">
          <div class="flex flex-col justify-between">
            <h4 class="text-xs uppercase text-gray-800 dark:text-white font-normal flex items-center">
              average score
            </h4>
            <span class={"text-base font-semibold tracking-wide flex items-center mt-2 #{text_color(:avg_score, @student.avg_score)}"}>
              <%= format_student_score(@student.avg_score) %>
            </span>
          </div>
          <div class="flex flex-col justify-between">
            <h4 class="text-xs uppercase text-gray-800 dark:text-white font-normal flex items-center">
              course completion
            </h4>
            <span class={"text-base font-semibold tracking-wide flex items-center mt-2 #{text_color(:progress, @student.progress)}"}>
              <%= format_percentage(@student.progress) %>
            </span>
          </div>
        </div>
        <%= if length(@survey_responses) > 0 do %>
          <div class="grid grid-cols-5 gap-4 w-full p-8">
            <%= for response <- @survey_responses do %>
              <div class="flex flex-col justify-between">
                <h4 class="text-xs uppercase text-gray-800 dark:text-white font-normal flex items-center">
                  <%= response.title %>
                </h4>
                <span class="text-base font-semibold tracking-wide text-gray-800 dark:text-white flex items-center mt-2">
                  <%= response.response || "-" %>
                </span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp text_color(metric_type, metric_value) when metric_type in [:avg_score, :progress] do
    case metric_value do
      nil -> "text-gray-800"
      value when value < 0.5 -> "text-red-600"
      value when value < 0.8 -> "text-yellow-600"
      _ -> "text-green-700"
    end
  end

  defp format_student_score(nil), do: "-"

  defp format_student_score(score) do
    format_percentage(score)
  end

  defp format_percentage(score) do
    {value, _} =
      (score * 100)
      |> Float.to_string()
      |> Integer.parse()

    "#{value}%"
  end
end
