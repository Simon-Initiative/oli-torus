defmodule OliWeb.DeliveryView do
  use OliWeb, :view

  alias Oli.Lti_1p3.ContextRoles

  def get_context_id(conn) do
    case Plug.Conn.get_session(conn, :lti_params) do
      %{context_id: context_id} ->
        context_id
      _ ->
        nil
    end
  end

  def user_role_is_student(conn, user) do
    context_id = get_context_id(conn)
    ContextRoles.has_role?(user, context_id, ContextRoles.get_role(:context_learner))
  end

  def user_role_text(conn, user) do
    context_id = get_context_id(conn)
    if ContextRoles.has_role?(user, context_id, ContextRoles.get_role(:context_learner)) do
      "Student"
    else
      "Instructor"
    end
  end

  def user_role_color(conn, user) do
    context_id = get_context_id(conn)
    if ContextRoles.has_role?(user, context_id, ContextRoles.get_role(:context_learner)) do
      "#3498db"
    else
      "#2ecc71"
    end
  end

  def account_linked?(user) do
    user.author_id != nil
  end

end
