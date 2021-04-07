defmodule OliWeb.ViewHelpers do

  def is_admin?(%{:assigns => assigns}) do
    admin_role_id = Oli.Accounts.SystemRole.role_id().admin
    assigns.current_author.system_role_id == admin_role_id
  end

  def preview_mode(%{assigns: assigns} = _conn) do
    Map.get(assigns, :preview_mode, false)
  end

end
