defmodule OliWeb.Components.Delivery.StudentDashboard do
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
        <.header current_user={@current_user} section={@section} preview_mode={@preview_mode} />
        <.section_details_header section={@section} student={@student}/>
        <Header.delivery_breadcrumb {assigns} />

        <.student_details student={@student} />

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
            {"Quizz Scores", path_for(:quizz_scores, @section_slug, @student_id, @preview_mode), nil, is_active_tab?(:quizz_scores, @active_tab)},
            {"Progress", path_for(:progress, @section_slug, @student_id, @preview_mode), nil, is_active_tab?(:progress, @active_tab)},
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

  defp logo_link(nil, _), do: Routes.delivery_path(OliWeb.Endpoint, :open_and_free_index)

  defp logo_link(section, preview_mode) do
    if preview_mode do
      Routes.student_dashboard_path(OliWeb.Endpoint, :preview, section.slug, :content)
    else
      Routes.page_delivery_path(OliWeb.Endpoint, :index, section.slug)
    end
  end

  attr :current_user, User
  attr :section, Section
  attr :preview_mode, :boolean, default: false

  def header(assigns) do
    ~H"""
      <div class="w-full bg-delivery-header text-white border-b border-slate-600">
        <div class="container mx-auto py-2 flex flex-row justify-between">
          <div class="flex-1 flex items-center">
            <a class="navbar-brand dark torus-logo my-1 mr-auto" href={logo_link(@section, @preview_mode)}>
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

  attr :student, User

  def student_details(assigns) do
    ~H"""
    <div class="w-full py-8">
      <div class="container mx-auto flex flex-row justify-between">
        <%= @student.name %>
      </div>
    </div>
    """
  end

  attr :section, Section
  attr :student, User

  def section_details_header(%{section: nil}), do: nil

  def section_details_header(assigns) do
    ~H"""
    <div class="w-full bg-delivery-header text-white py-8">
      <div class="container mx-auto flex flex-row justify-between">
        <div class="flex-1 flex items-center text-[1.5em]">
          <div class="font-bold text-slate-300">
            <%= @section.title %> > <%= @student.name %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
