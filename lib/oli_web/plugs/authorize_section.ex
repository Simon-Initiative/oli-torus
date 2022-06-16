defmodule Oli.Plugs.AuthorizeSection do
  import Plug.Conn
  import Phoenix.Controller

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Accounts.SystemRole

  @admin_role_id SystemRole.role_id() |> Map.get(:admin)

  def init(opts), do: opts

  def call(conn, _opts) do
    if is_admin?(conn) or is_instructor?(conn) do
      conn
    else
      conn
      |> put_view(OliWeb.PageDeliveryView)
      |> put_status(403)
      |> render("not_authorized.html")
      |> halt()
    end
  end

  defp is_admin?(conn) do
    case conn.assigns[:current_author] do
      %{system_role_id: system_role_id} -> system_role_id == @admin_role_id
      _ -> false
    end
  end

  defp is_instructor?(conn),
    do: ContextRoles.has_role?(conn.assigns[:current_user], conn.path_params["section_slug"], ContextRoles.get_role(:context_instructor))
end
