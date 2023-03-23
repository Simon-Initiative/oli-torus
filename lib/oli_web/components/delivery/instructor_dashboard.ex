defmodule OliWeb.Components.Delivery.InstructorDashboard do
  use Phoenix.Component

  import OliWeb.ViewHelpers, only: [brand_logo: 1]

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts.User
  alias OliWeb.Components.Delivery.UserAccountMenu
  alias OliWeb.Components.Delivery.CourseContentPanel
  alias OliWeb.Common.SessionContext

  defmodule PriorityAction do
    @enforce_keys [:type, :title, :description, :action_link]

    defstruct [
      :type,
      :title,
      :description,
      :action_link
    ]

    @type link_label() :: String.t()
    @type link_href() :: String.t()

    @type t() :: %__MODULE__{
            type: :email | :grade | :review,
            title: String.t(),
            description: String.t(),
            action_link: {link_label(), link_href()}
          }
  end

  def main_layout(assigns) do
    ~H"""
      <div class="flex-1 flex flex-col h-screen">
        <.header context={@context} current_user={@current_user} section_slug={@section_slug} preview_mode={@preview_mode} />
        <.section_details_header title={@title}/>

        <div class="flex-1 flex flex-col">

          <.actions />

          <div class="relative flex-1 flex flex-col pb-[60px]">

            <%= render_slot(@inner_block) %>

            <%= Phoenix.View.render OliWeb.LayoutView, "_delivery_footer.html", assigns %>
          </div>
        </div>
      </div>
    """
  end

  defp path_for(name, section_slug, _preview_mode = true) do
    case name do
      :learning_objectives ->
        Routes.learning_objectives_path(
          OliWeb.Endpoint,
          :preview,
          section_slug
        )

      :students ->
        Routes.students_path(
          OliWeb.Endpoint,
          :preview,
          section_slug
        )

      :content ->
        Routes.content_path(
          OliWeb.Endpoint,
          :preview,
          section_slug
        )

      :discussions ->
        Routes.discussions_path(
          OliWeb.Endpoint,
          :preview,
          section_slug
        )

      :course_discussion ->
        Routes.course_discussion_path(
          OliWeb.Endpoint,
          :preview,
          section_slug
        )

      :assignments ->
        Routes.assignments_path(
          OliWeb.Endpoint,
          :preview,
          section_slug
        )

      :manage ->
        Routes.manage_path(
          OliWeb.Endpoint,
          :preview,
          section_slug
        )
    end
  end

  defp path_for(name, section_slug, _preview_mode = false) do
    case name do
      :learning_objectives ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.LearningObjectivesLive,
          section_slug
        )

      :students ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.StudentsLive,
          section_slug
        )

      :content ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.ContentLive,
          section_slug
        )

      :discussions ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.DiscussionsLive,
          section_slug
        )

      :course_discussion ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.CourseDiscussionLive,
          section_slug
        )

      :assignments ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.AssignmentsLive,
          section_slug
        )

      :manage ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.ManageLive,
          section_slug
        )
    end
  end

  attr :active_tab, :atom,
    required: true,
    values: [
      :learning_objectives,
      :students,
      :content,
      :discussions,
      :course_discussion,
      :assignments,
      :manage
    ]

  attr :section_slug, :string, required: true
  attr :preview_mode, :boolean, required: true

  def tabs(assigns) do
    ~H"""
      <div class="container mx-auto my-4">
        <ul class="nav nav-tabs flex flex-col md:flex-row flex-wrap list-none border-b-0 pl-0 mb-4" id="tabs-tab"
          role="tablist">

          <%= for {label, href, badge, active} <- [
            {"Learning Objectives", path_for(:learning_objectives, @section_slug, @preview_mode), nil, is_active_tab?(:learning_objectives, @active_tab)},
            {"Students", path_for(:students, @section_slug, @preview_mode), nil, is_active_tab?(:students, @active_tab)},
            {"Modules", path_for(:content, @section_slug, @preview_mode), nil, is_active_tab?(:content, @active_tab)},
            {"Discussion Activity", path_for(:discussions, @section_slug, @preview_mode), nil, is_active_tab?(:discussions, @active_tab)},
            {"Course Discussion", path_for(:course_discussion, @section_slug, @preview_mode), nil, is_active_tab?(:course_discussion, @active_tab)},
            {"Assignments", path_for(:assignments, @section_slug, @preview_mode), nil, is_active_tab?(:assignments, @active_tab)},
            {"Manage", path_for(:manage, @section_slug, @preview_mode), nil, is_active_tab?(:manage, @active_tab)},
          ] do %>
            <li class="nav-item" role="presentation">
              <.link navigate={href}
                class={"
                  block
                  border-x-0 border-t-0 border-b-2
                  px-1
                  py-3
                  m-2
                  text-body-color
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

  defp logo_link(section_slug, preview_mode) do
    if preview_mode do
      Routes.content_path(OliWeb.Endpoint, :preview, section_slug)
    else
      Routes.page_delivery_path(OliWeb.Endpoint, :index, section_slug)
    end
  end

  attr :section_slug, :string, required: true
  attr :context, SessionContext
  attr :current_user, User
  attr :preview_mode, :boolean, default: false

  def header(assigns) do
    ~H"""
      <div class="w-full bg-delivery-header text-white border-b border-slate-600">
        <div class="container mx-auto py-2 flex flex-row justify-between">
          <div class="flex-1 flex items-center">
            <a class="navbar-brand dark torus-logo my-1 mr-auto" href={logo_link(@section_slug, @preview_mode)}>
              <%= brand_logo(Map.merge(assigns, %{class: "d-inline-block align-top mr-2"})) %>
            </a>
          </div>
          <%= if @preview_mode do %>
            <UserAccountMenu.preview_user />
          <% else %>
            <UserAccountMenu.menu is_liveview={true} context={@context} current_user={@current_user} />
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

  attr :title, :string, required: true

  def section_details_header(assigns) do
    ~H"""
    <div class="w-full bg-delivery-header text-white py-8">
      <div class="container mx-auto flex flex-row justify-between">
        <div class="flex-1 flex items-center text-[1.5em]">
          <div class="font-bold text-slate-300">
            <%= @title %>
          </div>
          <%!-- <div class="border-l border-white ml-4 pl-4">
            Section 2360
          </div> --%>
          <%!-- <div class="font-thin border-l border-white ml-4 pl-4">
            Mon/Wed 12:00 PM
          </div> --%>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Takes a list of actions and renders a set of action cards

  E.g.
    ```
    <.actions actions=[%PriorityAction{ type: :email, title: "Send an email to students reminding of add/drop period", description: "Send before add/drop period ends on 9/23/2022", action_link: {"Send", "#"} }] />
    ```
  """
  attr :actions, :list, default: []

  def actions(assigns) do
    ~H"""
      <%= if Enum.count(@actions) > 0 do %>
          <div class="w-full py-4">
            <div class="container mx-auto flex-col">
              <div class="py-4 font-bold">
                Top priority actions to take for this class
              </div>
              <div class="flex flex-row overflow-x-auto">
                <%= for action <- @actions do %>
                  <.action_card action={action} />
                <% end %>
              </div>
            </div>
          </div>
      <% end %>
    """
  end

  attr :action, PriorityAction, required: true

  def action_card(assigns) do
    ~H"""
      <div class="flex flex-col bg-white dark:bg-gray-800 shadow p-4 mr-4 max-w-[300px] shrink-0">
        <div class="flex my-2">
          <span class={"rounded-full py-1 px-6 #{badge_bg_color(@action.type)} text-white"}>
            <%= badge_title(@action.type) %>
          </span>
        </div>
        <div class="font-semibold my-2">
          <%= @action.title %>
        </div>
        <div class="flex-1 text-gray-500 my-2">
          <%= @action.description %>
        </div>
        <div class="flex flex-row mt-4">
          <a href={@action.action_link |> elem(1)} class="btn flex-1 bg-delivery-primary hover:bg-delivery-primary-700 text-white hover:text-white text-center">
            <%= @action.action_link |> elem(0) %>
          </a>
          <button class="btn btn-link text-delivery-primary hover:text-delivery-primary-700">
            Dismiss
          </button>
        </div>
      </div>
    """
  end

  defp badge_title(:email), do: "Email"
  defp badge_title(:grade), do: "Grade"
  defp badge_title(:review), do: "Review"
  defp badge_title(_), do: "Action"

  defp badge_bg_color(:email), do: "bg-green-700"
  defp badge_bg_color(:grade), do: "bg-red-700"
  defp badge_bg_color(:review), do: "bg-fuchsia-700"
  defp badge_bg_color(_), do: "bg-gray-700"

  def learning_objectives(assigns) do
    ~H"""
      <.tabs active_tab={:learning_objectives} section_slug={@section_slug} preview_mode={@preview_mode} />

      <p class="mx-auto">Not available yet</p>
    """
  end

  def students(assigns) do
    ~H"""
      <.tabs active_tab={:students} section_slug={@section_slug} preview_mode={@preview_mode} />

      <p class="mx-auto">Not available yet</p>
    """
  end

  def content(assigns) do
    ~H"""
      <.tabs active_tab={:content} section_slug={@section_slug} preview_mode={@preview_mode} />

      <CourseContentPanel.course_content_panel {assigns} />
    """
  end

  def discussions(assigns) do
    ~H"""
      <.tabs active_tab={:discussions} section_slug={@section_slug} preview_mode={@preview_mode} />

      <.live_component
        id="discussion_activity_table"
        module={OliWeb.Components.Delivery.DiscussionActivity}
        limit={@limit}
        filter={@filter}
        offset={@offset}
        count={@count}
        collab_space_table_model={@collab_space_table_model}
        discussion_table_model={@discussion_table_model}
        parent_component_id={@parent_component_id} />
    """
  end

  def course_discussion(assigns) do
    ~H"""
      <.tabs active_tab={:course_discussion} section_slug={@section_slug} preview_mode={@preview_mode} />
      <div class="container mx-auto mt-3 mb-5">
        <div class="bg-white dark:bg-gray-800 p-8 shadow">
         <%= if @collab_space_config do%>
          <%= live_render(@socket, OliWeb.CollaborationLive.CollabSpaceView, id: "course_discussion",
            session: %{
              "collab_space_config" => @collab_space_config,
              "section_slug" => @section_slug,
              "resource_slug" => @revision_slug,
              "is_instructor" => true,
              "title" => "Course Discussion"
            })
          %>
          <% else %>
              <h6>There is no collaboration space configured for this Course</h6>
          <% end %>
        </div>
      </div>
    """
  end

  def assignments(assigns) do
    ~H"""
      <.tabs active_tab={:assignments} section_slug={@section_slug} preview_mode={@preview_mode} />

      <p class="mx-auto">Not available yet</p>
    """
  end

  def manage(assigns) do
    ~H"""
      <.tabs active_tab={:manage} section_slug={@section_slug} preview_mode={@preview_mode} />
      <div class="container mx-auto mt-3 mb-5">
        <div class="bg-white dark:bg-gray-800 p-8 shadow">
          <%= live_render(@socket, OliWeb.Sections.OverviewView, id: "overview", session: %{"section_slug" => @section_slug}) %>
        </div>
      </div>
    """
  end
end
