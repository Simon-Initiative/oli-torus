defmodule OliWeb.DeliveryView do
  use OliWeb, :view

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Lti_1p3.Tool.ContextRoles
  alias Lti_1p3.Tool.PlatformRoles

  def get_section_slug(conn) do
    case Sections.get_section_from_lti_params(conn.assigns.lti_params) do
      %Section{slug: slug} -> slug
      _ -> nil
    end
  end


  def user_role_is_student(conn, user) do
    section_slug = get_section_slug(conn)

    ContextRoles.has_role?(user, section_slug, ContextRoles.get_role(:context_learner))
  end

  def user_role_text(conn, user) do
    section_slug = get_section_slug(conn)

    cond do
      PlatformRoles.has_role?(user, PlatformRoles.get_role(:system_administrator))
      || PlatformRoles.has_role?(user, PlatformRoles.get_role(:institution_administrator))
      || ContextRoles.has_role?(user, section_slug, ContextRoles.get_role(:context_administrator)) ->
        "Administrator"
      ContextRoles.has_role?(user, section_slug, ContextRoles.get_role(:context_instructor)) ->
        "Instructor"
      ContextRoles.has_role?(user, section_slug, ContextRoles.get_role(:context_student)) ->
        "Student"
      true ->
        "Student"
    end
  end

  def user_role_color(conn, user) do
    section_slug = get_section_slug(conn)

    cond do
      PlatformRoles.has_role?(user, PlatformRoles.get_role(:system_administrator))
      || PlatformRoles.has_role?(user, PlatformRoles.get_role(:institution_administrator))
      || ContextRoles.has_role?(user, section_slug, ContextRoles.get_role(:context_administrator)) ->
        "#f39c12"
      ContextRoles.has_role?(user, section_slug, ContextRoles.get_role(:context_instructor)) ->
        "#2ecc71"
      ContextRoles.has_role?(user, section_slug, ContextRoles.get_role(:context_learner)) ->
        "#3498db"
      true ->
        "#3498db"
    end
  end

  def account_linked?(user) do
    user.author_id != nil
  end

  def user_icon(conn, user) do
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
          <% IO.inspect user.picture %>
          <img src="<%= user.picture %>" class="rounded-circle" />
        </div>
        """
    end
  end

end
