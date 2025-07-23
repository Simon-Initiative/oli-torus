defmodule OliWeb.Components.Delivery.Utils do
  @moduledoc """
  NOTICE: MODULE DEPRECATED - USE OliWeb.Components.Utils INSTEAD
  If there are functions here that are required, copy them to OliWeb.Components.Utils.
  """
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias Oli.Interop.CustomActivities.User
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections.Section
  alias Oli.Accounts
  alias Oli.Accounts.{User, Author, SystemRole}
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS
  alias Lti_1p3.Roles.ContextRoles
  alias Lti_1p3.Roles.PlatformRoles

  import Oli.Utils, only: [identity: 1]

  def is_preview_mode?(assigns) do
    assigns[:preview_mode] == true
  end

  def user_signed_in?(assigns) do
    assigns[:current_user]
  end

  @doc """
  Returns true if a user is signed in as guest
  """
  def user_is_guest?(assigns) do
    case assigns[:current_user] do
      %User{guest: true} ->
        true

      _ ->
        false
    end
  end

  @doc """
  Returns true if a user is signed in as an independent learner
  """
  def user_is_independent_learner?(current_user) do
    case current_user do
      %User{independent_learner: true} ->
        true

      _ ->
        false
    end
  end

  def user_name(user) do
    case user do
      %User{guest: true} ->
        "Guest"

      %User{name: name} ->
        name

      %Author{name: name} ->
        name

      _ ->
        ""
    end
  end

  def is_open_and_free_section?(assigns) do
    case assigns[:section] do
      %Section{open_and_free: open_and_free} ->
        open_and_free

      _ ->
        false
    end
  end

  def is_independent_learner?(assigns) do
    case assigns[:current_user] do
      %User{independent_learner: independent_learner} ->
        independent_learner

      _ ->
        false
    end
  end

  def logo_link_path(assigns) do
    cond do
      is_preview_mode?(assigns) ->
        "#"

      is_open_and_free_section?(assigns) or is_independent_learner?(assigns) ->
        ~p"/workspaces/student"

      true ->
        Routes.static_page_path(OliWeb.Endpoint, :index)
    end
  end

  def user_role_text(section, user) do
    case user_role(section, user) do
      :administrator ->
        "Administrator"

      :instructor ->
        "Instructor"

      :student ->
        "Student"

      :system_admin ->
        "System Admin"

      _ ->
        ""
    end
  end

  def user_role_is_student(assigns, user) do
    case user_role(assigns[:section], user) do
      :student ->
        true

      :other ->
        true

      _ ->
        false
    end
  end

  def user_role_color(section, user) do
    case user_role(section, user) do
      :administrator ->
        "#f39c12"

      :instructor ->
        "#2ecc71"

      :student ->
        "#3498db"

      :system_admin ->
        "#f39c12"

      _ ->
        ""
    end
  end

  attr :on_expand, Phoenix.LiveView.JS,
    default: JS.dispatch("click", to: "button[aria-expanded='false'][data-bs-toggle='collapse']")

  attr :on_collapse, Phoenix.LiveView.JS,
    default: JS.dispatch("click", to: "button[aria-expanded='true'][data-bs-toggle='collapse']")

  def toggle_expand_button(assigns) do
    ~H"""
    <div class="flex items-center justify-start w-32 px-2 text-sm font-bold text-[#0080FF] dark:text-[#0062F2]">
      <button
        id="expand_all_button"
        phx-click={@on_expand |> JS.hide() |> JS.show(to: "#collapse_all_button", display: "flex")}
        class="flex space-x-3"
      >
        <Icons.expand />
        <span>Expand All</span>
      </button>

      <button
        id="collapse_all_button"
        phx-click={@on_collapse |> JS.hide() |> JS.show(to: "#expand_all_button", display: "flex")}
        class="hidden space-x-3"
      >
        <Icons.collapse />
        <span>Collapse All</span>
      </button>
    </div>
    """
  end

  attr :search_term, :string, default: ""
  attr :on_search, :string, default: "search"
  attr :on_change, :string, default: "search"
  attr :on_clear_search, :string, default: "clear_search"
  attr :rest, :global, include: ~w(class placeholder)

  def search_box(assigns) do
    ~H"""
    <form class={["flex flex-row", @rest[:class]]} phx-submit={@on_search} phx-change={@on_change}>
      <div class="flex-1 relative">
        <i class="fa-solid fa-search absolute left-4 top-4 text-gray-400 pointer-events-none text-lg">
        </i>
        <input
          type="text"
          name="search_term"
          value={@search_term}
          placeholder={@rest[:placeholder]}
          class="w-full border border-gray-400 dark:border-gray-700 rounded-lg px-12 py-3"
          phx-debounce="500"
        />
        <button
          :if={@search_term not in ["", nil]}
          type="button"
          class="absolute right-0 top-0 bottom-0 py-3 px-4"
          phx-click={@on_clear_search}
        >
          <i class="fa-solid fa-xmark text-lg"></i>
        </button>
      </div>
    </form>
    """
  end

  attr(:current_user, User)

  def user_icon(%{current_user: _} = assigns) do
    ~H"""
    <%= case @current_user.picture do %>
      <% nil -> %>
        <.user_icon />
      <% picture -> %>
        <div class="user-icon">
          <img src={picture} referrerpolicy="no-referrer" class="rounded-full" />
        </div>
    <% end %>
    """
  end

  def user_icon(assigns) do
    ~H"""
    <div class="user-icon">
      <div class="user-img rounded-full">
        <i class="fa-solid fa-circle-user fa-2xl mt-[-1px] ml-[-1px] text-gray-600"></i>
      </div>
    </div>
    """
  end

  @admin_roles [
    PlatformRoles.get_role(:system_administrator),
    PlatformRoles.get_role(:institution_administrator),
    ContextRoles.get_role(:context_administrator)
  ]

  @instructor_roles [
    PlatformRoles.get_role(:institution_instructor),
    ContextRoles.get_role(:context_instructor),
    ContextRoles.get_role(:context_content_developer)
  ]

  @student_roles [
    PlatformRoles.get_role(:institution_student),
    PlatformRoles.get_role(:institution_learner),
    ContextRoles.get_role(:context_learner)
  ]

  @system_admin_role_ids [
    SystemRole.role_id().system_admin,
    SystemRole.role_id().account_admin,
    SystemRole.role_id().content_admin
  ]

  def user_role(section, user) do
    case user do
      %Author{system_role_id: system_role_id} when system_role_id in @system_admin_role_ids ->
        :system_admin

      %Author{} ->
        :other

      _ ->
        case section do
          %Section{slug: section_slug} ->
            cond do
              PlatformRoles.has_roles?(user, @admin_roles, :any) ||
                  ContextRoles.has_roles?(user, section_slug, @admin_roles, :any) ->
                :administrator

              PlatformRoles.has_roles?(user, @instructor_roles, :any) ||
                  ContextRoles.has_roles?(user, section_slug, @instructor_roles, :any) ->
                :instructor

              PlatformRoles.has_roles?(user, @student_roles, :any) ||
                  ContextRoles.has_roles?(user, section_slug, @student_roles, :any) ->
                :student

              true ->
                :other
            end

          _ ->
            case user do
              %User{can_create_sections: can_create_sections} ->
                cond do
                  PlatformRoles.has_roles?(user, @admin_roles, :any) ->
                    :administrator

                  PlatformRoles.has_roles?(user, @instructor_roles, :any) || can_create_sections ->
                    :instructor

                  PlatformRoles.has_roles?(user, @student_roles, :any) ->
                    :student

                  true ->
                    :other
                end

              _ ->
                :other
            end
        end
    end
  end

  def account_linked?(user) do
    case user do
      %User{author_id: author_id} ->
        author_id != nil

      _ ->
        false
    end
  end

  def timezone_preference(%User{} = user), do: Accounts.get_user_preference(user, :timezone)
  def timezone_preference(%Author{} = user), do: Accounts.get_author_preference(user, :timezone)

  def linked_author_account(%User{author: %Author{email: email}}), do: email
  def linked_author_account(_), do: nil

  def maybe_section_slug(assigns) do
    case assigns[:section] do
      %Section{slug: slug} ->
        slug

      _ ->
        ""
    end
  end

  def delivery_breadcrumbs?(assigns),
    do:
      Map.has_key?(assigns, :breadcrumbs) and is_list(Map.get(assigns, :breadcrumbs)) and
        length(Map.get(assigns, :breadcrumbs, [])) > 0

  def socket_or_conn(%{socket: socket} = _assigns), do: socket
  def socket_or_conn(%{conn: conn} = _assigns), do: conn

  attr(:percent, :integer, required: true)
  attr(:show_percent, :boolean, default: false)
  attr(:width, :string, default: "100%")

  def progress_bar(assigns) do
    ~H"""
    <div class="my-2 flex flex-row items-center">
      <div class="font-bold"><%= @percent %>%</div>
      <div class="flex-1 ml-3">
        <div class={"w-[#{@width}] rounded-full bg-gray-200 h-2"}>
          <div class="rounded-full bg-green-600 h-2" style={"width: #{@percent}%"}></div>
        </div>
      </div>
    </div>
    """
  end

  attr :target_selector, :string, required: true, doc: "CSS Selector of the elements to hide/show"
  attr :class, :string, default: "", doc: "CSS extra classes for the button"

  attr :on_toggle, :any,
    default: &identity/1,
    doc: "Callback function to execute after toggling visibility"

  def toggle_visibility_button(assigns) do
    ~H"""
    <button
      id="hide_completed_button"
      phx-click={hide_completed(@target_selector, @on_toggle)}
      class={["self-stretch justify-center items-center gap-2 flex", @class]}
    >
      <div class="w-4 h-4"><Icons.hidden /></div>
      <span>Hide Completed</span>
    </button>
    <button
      id="show_completed_button"
      phx-click={show_completed(@target_selector, @on_toggle)}
      class={["hidden self-stretch justify-center items-center gap-2", @class]}
    >
      <div class="w-4 h-4"><Icons.visible /></div>
      <span>Show Completed</span>
    </button>
    """
  end

  def hide_completed(target_selector, on_toggle) do
    JS.hide()
    |> JS.add_class("hidden", to: target_selector)
    |> JS.show(to: "#show_completed_button", display: "flex")
    |> on_toggle.()
  end

  def show_completed(target_selector, on_toggle) do
    JS.hide()
    |> JS.remove_class("hidden", to: target_selector)
    |> JS.show(to: "#hide_completed_button", display: "flex")
    |> on_toggle.()
  end

  @doc """
  Returns the course week number of a resource based on the section start date.
  It considers that weeks start on Sunday, regardless of the section start date that could be any day of the week.
  """

  def week_number(section_start_datetime, resource_datetime, week_start_date \\ :sunday)
  def week_number(_section_start_datetime, nil, _week_start_date), do: "not yet scheduled"
  def week_number(nil, _, _week_start_date), do: "not yet scheduled"

  def week_number(_section_start_datetime, "not yet scheduled", _week_start_date),
    do: "not yet scheduled"

  def week_number(section_start_datetime, resource_datetime, week_start_date) do
    course_first_sunday =
      section_start_datetime
      |> DateTime.to_date()
      |> Date.beginning_of_week(week_start_date)

    resource_datetime
    |> DateTime.to_date()
    |> Date.diff(course_first_sunday)
    |> Integer.floor_div(7)
    |> Kernel.+(1)
  end

  def get_resource_scheduled_date(resource_id, scheduled_dates, ctx) do
    case scheduled_dates[resource_id] do
      %{end_date: nil} ->
        "No due date"

      data ->
        "#{scheduled_date_type(data.scheduled_type)} #{OliWeb.Common.FormatDateTime.date(data.end_date, ctx)}"
    end
  end

  defp scheduled_date_type(:read_by), do: "Read by"
  defp scheduled_date_type(:inclass_activity), do: "In class on"
  defp scheduled_date_type(_), do: "Due by"
end
