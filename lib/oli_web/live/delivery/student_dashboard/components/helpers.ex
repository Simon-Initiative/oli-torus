defmodule OliWeb.Delivery.StudentDashboard.Components.Helpers do
  use Phoenix.Component

  import OliWeb.ViewHelpers, only: [brand_logo: 1]

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Components.Delivery.UserAccountMenu
  alias OliWeb.Components.Header

  attr :current_user, User
  attr :student, User
  attr :section, Section
  attr :breadcrumbs, :list, required: true
  attr :socket_or_conn, :any, required: true
  attr :preview_mode, :boolean, default: false

  def main_layout(assigns) do
    ~H"""
      <div class="flex-1 flex flex-col h-screen">
        <.header current_user={@current_user} student={@student} section={@section} preview_mode={@preview_mode} />
        <Header.delivery_breadcrumb {assigns} />

        <div class="flex-1 flex flex-col">
          <div class="relative flex-1 flex flex-col pb-[60px]">
            <%= render_slot(@inner_block) %>
            <%= Phoenix.View.render OliWeb.LayoutView, "_delivery_footer.html", assigns %>
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

  attr :active_tab, :atom,
    required: true,
    values: [
      :content,
      :learning_objectives,
      :quizz_scores,
      :progress
    ]

  attr :section_slug, :string, required: true
  attr :student_id, :string, required: true
  attr :preview_mode, :boolean, required: true

  def tabs(assigns) do
    ~H"""
      <div class="container mx-auto my-4">
        <ul class="nav nav-tabs flex flex-col md:flex-row flex-wrap list-none border-b-0 pl-0 mb-4" id="tabs-tab"
          role="tablist">

          <%= for {label, href, badge, active} <- [
            {"Content", path_for(:content, @section_slug, @student_id, @preview_mode), nil, is_active_tab?(:content, @active_tab)},
            {"Learning Objectives", path_for(:learning_objectives, @section_slug, @student_id, @preview_mode), nil, is_active_tab?(:learning_objectives, @active_tab)},
            {"Quiz Scores", path_for(:quizz_scores, @section_slug, @student_id, @preview_mode), nil, is_active_tab?(:quizz_scores, @active_tab)},
            {"Progress", path_for(:progress, @section_slug, @student_id, @preview_mode), nil, is_active_tab?(:progress, @active_tab)},
            {"Actions", path_for(:actions, @section_slug, @student_id, @preview_mode), nil, is_active_tab?(:actions, @active_tab)},
          ] do %>
            <li class="nav-item" role="presentation">
              <.link patch={href}
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
                  <%= if badge do %>
                  <span class="text-xs inline-block py-1 px-2 ml-2 leading-none text-center whitespace-nowrap align-baseline font-bold bg-delivery-primary text-white rounded"><%= badge %></span>
                  <% end %>
              </.link>
            </li>
          <% end %>

        </ul>
      </div>
    """
  end

  defp is_active_tab?(tab, active_tab), do: tab == active_tab

  defp logo_link(nil, _, _), do: Routes.delivery_path(OliWeb.Endpoint, :open_and_free_index)

  defp logo_link(section, student_id, preview_mode) do
    if preview_mode do
      Routes.student_dashboard_path(OliWeb.Endpoint, :preview, section.slug, student_id, :content)
    else
      Routes.page_delivery_path(OliWeb.Endpoint, :index, section.slug)
    end
  end

  attr :current_user, User
  attr :student, User
  attr :section, Section
  attr :preview_mode, :boolean, default: false

  def header(assigns) do
    ~H"""
      <div class="w-full bg-delivery-header text-white border-b border-slate-600">
        <div class="container mx-auto py-2 flex flex-row justify-between">
          <div class="flex-1 flex items-center">
            <a class="navbar-brand dark torus-logo my-1 mr-auto" href={logo_link(@section, @student.id, @preview_mode)}>
              <%= brand_logo(Map.merge(assigns, %{class: "d-inline-block align-top mr-2"})) %>
            </a>
          </div>
          <%= if @preview_mode do %>
            <UserAccountMenu.preview_user />
          <% else %>
            <UserAccountMenu.menu current_user={@current_user} />
          <% end %>
          <div class="flex items-center border-l border-slate-300">
            <button
              class="
                btn
                rounded
                ml-4
                no-underline
                text-slate-100
                hover:no-underline
                hover:bg-delivery-header-700
                active:bg-delivery-header-600
              "
              data-bs-toggle="modal"
              data-bs-target="#help-modal">
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
      field :title, :string
      field :response, :string
    end
  end

  attr :student, User
  attr :survey_responses, :list

  def student_details(assigns) do
    ~H"""
      <div id="student_details_card" class="flex flex-col sm:flex-row items-center mx-10">
        <div class="flex shrink-0 mb-6 sm:mb-0 sm:mr-6">
          <%= if @student.picture do %>
            <img src={@student.picture} class="rounded-full h-52 w-52" referrerPolicy="no-referrer" />
          <% else %>
              <i class="h-52 w-52 fa-solid fa-circle-user fa-2xl mt-[-1px] ml-[-1px] text-gray-200"></i>
          <% end %>
        </div>
        <div class="flex flex-col divide-y divide-gray-100 w-full bg-white">
          <div class="grid grid-cols-5 gap-4 w-full p-8">
            <div class="flex flex-col justify-between">
              <h4 class="text-xs uppercase text-gray-800 font-normal flex items-center">average score</h4>
              <span class={"text-base font-semibold tracking-wide flex items-center mt-2 #{text_color(:avg_score, @student.avg_score)}"}><%= format_student_score(@student.avg_score) %></span>
            </div>
            <div class="flex flex-col justify-between">
              <h4 class="text-xs uppercase text-gray-800 font-normal flex items-center">course completion</h4>
              <span class={"text-base font-semibold tracking-wide flex items-center mt-2 #{text_color(:progress, @student.progress)}"}><%= format_percentage(@student.progress) %></span>
            </div>
            <div class="flex flex-col justify-between">
              <h4 class="text-xs uppercase text-gray-800 font-normal flex items-center">platform engagement <i class="fa fa-info-circle text-primary h-3 w-3 ml-2"></i></h4>
              <span class={"text-base font-semibold tracking-wide flex items-center mt-2 #{text_color(:engagement, @student.engagement)}"}><%= @student.engagement %></span>
            </div>
          </div>
          <%= if length(@survey_responses) > 0 do%>
            <div class="grid grid-cols-5 gap-4 w-full p-8">
              <%= for response <- @survey_responses do %>
                <div class="flex flex-col justify-between">
                  <h4 class="text-xs uppercase text-gray-800 font-normal flex items-center"><%= response.title %></h4>
                  <span class="text-base font-semibold tracking-wide text-gray-800 flex items-center mt-2"><%= response.response || "-" %></span>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    """
  end

  attr :section_title, :string
  attr :student_name, :string

  def section_details_header(%{section: nil}), do: nil

  def section_details_header(assigns) do
    ~H"""
      <div id="section_details_header" class="flex flex-row justify-between items-center h-20 w-full py-6 px-10">
        <span phx-click="breadcrumb-navigate" class="text-sm tracking-wide text-gray-800 underline font-normal cursor-pointer"><%= @section_title %> | Students  >  <%= @student_name %></span>
        <button class="torus-button flex justify-center primary h-9 w-48">Email Student</button>
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

  defp text_color(:engagement, metric_value) do
    case metric_value do
      nil -> "text-gray-800"
      "Low" -> "text-red-600"
      "Medium" -> "text-yellow-600"
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
