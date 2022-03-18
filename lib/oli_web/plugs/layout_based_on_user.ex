defmodule Oli.Plugs.LayoutBasedOnUser do
  alias Oli.Accounts.{Author, SystemRole}
  alias Phoenix.Controller

  def init(_params) do
  end

  def call(conn, _params) do
    admin_role_id = SystemRole.role_id().admin

    # If someone is logged in as a system admin, prioritize that (although they
    # might be logged in as instructor) and set the root layout to be workspace.
    case {conn.assigns.current_author, conn.assigns.current_user} do
      {%Author{system_role_id: ^admin_role_id}, _} ->
        Controller.put_root_layout(conn, {OliWeb.LayoutView, "workspace.html"})

      _ ->
        Controller.put_root_layout(conn, {OliWeb.LayoutView, "delivery.html"})
    end
  end
end
