defmodule OliWeb.DeliveryView do
  use OliWeb, :view

  alias Lti_1p3.ContextRoles
  alias Lti_1p3.PlatformRoles

  def get_context_id(conn) do
    case conn.assigns.lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["id"] do
      nil -> nil
      context_id -> context_id
    end
  end

  def user_role_is_student(conn, user) do
    context_id = get_context_id(conn)
    ContextRoles.has_role?(user, context_id, ContextRoles.get_role(:context_learner))
  end

  def user_role_text(conn, user) do
    context_id = get_context_id(conn)
    cond do
      PlatformRoles.has_role?(user, PlatformRoles.get_role(:system_administrator))
      || PlatformRoles.has_role?(user, PlatformRoles.get_role(:institution_administrator))
      || ContextRoles.has_role?(user, context_id, ContextRoles.get_role(:context_administrator)) ->
        "Administrator"
      ContextRoles.has_role?(user, context_id, ContextRoles.get_role(:context_instructor)) ->
        "Instructor"
      ContextRoles.has_role?(user, context_id, ContextRoles.get_role(:context_student)) ->
        "Student"
      true ->
        "Student"
    end
  end

  def user_role_color(conn, user) do
    context_id = get_context_id(conn)
    cond do
      PlatformRoles.has_role?(user, PlatformRoles.get_role(:system_administrator))
      || PlatformRoles.has_role?(user, PlatformRoles.get_role(:institution_administrator))
      || ContextRoles.has_role?(user, context_id, ContextRoles.get_role(:context_administrator)) ->
        "#f39c12"
      ContextRoles.has_role?(user, context_id, ContextRoles.get_role(:context_instructor)) ->
        "#2ecc71"
      ContextRoles.has_role?(user, context_id, ContextRoles.get_role(:context_learner)) ->
        "#3498db"
      true ->
        "#3498db"
    end
  end

  def account_linked?(user) do
    user.author_id != nil
  end

end
