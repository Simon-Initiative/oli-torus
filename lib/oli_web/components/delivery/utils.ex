defmodule OliWeb.Components.Delivery.Utils do
  use Phoenix.Component

  alias Oli.Interop.CustomActivities.User
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Accounts
  alias Oli.Accounts.{User, Author, SystemRole}
  alias Lti_1p3.Tool.ContextRoles
  alias Lti_1p3.Tool.PlatformRoles

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
        Routes.delivery_path(OliWeb.Endpoint, :open_and_free_index)

      user_signed_in?(assigns) ->
        Routes.delivery_path(OliWeb.Endpoint, :index)

      true ->
        Routes.static_page_path(OliWeb.Endpoint, :index)
    end
  end

  def user_role_text(section, user) do
    case user_role(section, user) do
      :open_and_free ->
        "Independent"

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
      :open_and_free ->
        !Sections.is_independent_instructor?(user)

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
      :open_and_free ->
        "#2C67C4"

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

  attr :current_user, User

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
    ContextRoles.get_role(:context_instructor)
  ]

  @student_roles [
    PlatformRoles.get_role(:institution_student),
    PlatformRoles.get_role(:institution_learner),
    ContextRoles.get_role(:context_learner)
  ]

  @system_admin_role_id SystemRole.role_id().admin

  def user_role(section, user) do
    case section do
      %Section{open_and_free: open_and_free, slug: section_slug} ->
        cond do
          open_and_free ->
            :open_and_free

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
            case user do
              %Author{system_role_id: @system_admin_role_id} ->
                :system_admin

              _ ->
                :other
            end
        end

      _ ->
        case user do
          %User{guest: is_guest?} = user ->
            cond do
              is_guest? ->
                :open_and_free

              PlatformRoles.has_roles?(user, @admin_roles, :any) ->
                :administrator

              PlatformRoles.has_roles?(user, @instructor_roles, :any) ->
                :instructor

              PlatformRoles.has_roles?(user, @student_roles, :any) ->
                :student

              true ->
                :other
            end

          %Author{system_role_id: @system_admin_role_id} ->
            :system_admin

          _ ->
            :other
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

  attr :percent, :integer, required: true
  attr :width, :string, default: "100%"

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

  def format_date(date), do: Oli.Cldr.Date.to_string(date) |> elem(1)

  def format_duration(%Timex.Duration{} = duration),
    do: Timex.format_duration(duration, :humanized)
end
