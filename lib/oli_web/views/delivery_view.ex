defmodule OliWeb.DeliveryView do
  use OliWeb, :view

  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.ContextRoles
  alias Lti_1p3.Tool.PlatformRoles

  @admin_roles [
    PlatformRoles.get_role(:system_administrator),
    PlatformRoles.get_role(:institution_administrator),
    ContextRoles.get_role(:context_administrator),
  ]

  @instructor_roles [
    PlatformRoles.get_role(:institution_instructor),
    ContextRoles.get_role(:context_instructor),
  ]

  @student_roles [
    PlatformRoles.get_role(:institution_student),
    PlatformRoles.get_role(:institution_learner),
    ContextRoles.get_role(:context_learner),
  ]

  def user_role_is_student(conn, user) do
    section = Sections.get_section_from_lti_params(conn.assigns.lti_params)

    PlatformRoles.has_roles?(user, @student_roles, :any) || ContextRoles.has_roles?(user, section.slug, @student_roles, :any)
  end

  def user_role_text(conn, user) do
    section = Sections.get_section_from_lti_params(conn.assigns.lti_params)

    cond do
      section.open_and_free ->
        "Open and Free"
      PlatformRoles.has_roles?(user, @admin_roles, :any) || ContextRoles.has_roles?(user, section.slug, @admin_roles, :any) ->
        "Administrator"
      PlatformRoles.has_roles?(user, @instructor_roles, :any) || ContextRoles.has_roles?(user, section.slug, @instructor_roles, :any) ->
        "Instructor"
      PlatformRoles.has_roles?(user, @student_roles, :any) || ContextRoles.has_roles?(user, section.slug, @student_roles, :any) ->
        "Student"
      true ->
        ""
    end
  end

  def user_role_color(conn, user) do
    section = Sections.get_section_from_lti_params(conn.assigns.lti_params)

    cond do
      section.open_and_free ->
        "#2C67C4"
      PlatformRoles.has_roles?(user, @admin_roles, :any) || ContextRoles.has_roles?(user, section.slug, @admin_roles, :any) ->
        "#f39c12"
      PlatformRoles.has_roles?(user, @instructor_roles, :any) || ContextRoles.has_roles?(user, section.slug, @instructor_roles, :any) ->
        "#2ecc71"
      PlatformRoles.has_roles?(user, @student_roles, :any) || ContextRoles.has_roles?(user, section.slug, @student_roles, :any) ->
        "#3498db"
      true ->
        "#3498db"
    end
  end

  def account_linked?(user) do
    user.author_id != nil
  end

  def user_icon(_conn, user) do
    case user.picture do
      nil ->
        ~E"""
        <div class="user-icon">
          <div class="user-img rounded-circle">
            <span class="material-icons text-secondary">account_circle</span>
          </div>
        </div>
        """
      picture ->
        ~E"""
        <div class="user-icon">
          <img src="<%= picture %>" class="rounded-circle" />
        </div>
        """
    end
  end

end
