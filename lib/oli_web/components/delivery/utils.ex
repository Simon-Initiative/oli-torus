defmodule OliWeb.Components.Delivery.Utils do
  use Phoenix.Component

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Accounts.User
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
      %{guest: true} ->
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
      %{independent_learner: true} ->
        true

      _ ->
        false
    end
  end

  def user_name(user) do
    case user do
      %{guest: true} ->
        "Guest"

      %{name: name} ->
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

  def user_role_text(assigns, user) do
    case user_role(assigns[:section], user) do
      :open_and_free ->
        "Independent"

      :administrator ->
        "Administrator"

      :instructor ->
        "Instructor"

      :student ->
        "Student"

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

  def user_role_color(assigns, user) do
    case user_role(assigns[:section], user) do
      :open_and_free ->
        "#2C67C4"

      :administrator ->
        "#f39c12"

      :instructor ->
        "#2ecc71"

      :student ->
        "#3498db"

      _ ->
        ""
    end
  end

  def user_icon(%{current_user: current_user} = assigns) do
    case current_user.picture do
      nil ->
        user_icon(%{})

      _picture ->
        ~H"""
        <div class="user-icon">
          <img src={@current_user.picture} referrerpolicy="no-referrer" class="rounded-full" />
        </div>
        """
    end
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

  defp user_role(section, user) do
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
            :other
        end

      _ ->
        cond do
          user.guest ->
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
    end
  end

  def account_linked?(user) do
    user.author_id != nil
  end

  def maybe_section_slug(assigns) do
    case assigns[:section] do
      %Section{slug: slug} ->
        slug

      _ ->
        ""
    end
  end
end
