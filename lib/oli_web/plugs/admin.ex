defmodule Oli.Plugs.EnsureAdmin do
  import Plug.Conn
  import Phoenix.Controller
  alias Oli.Accounts.SystemRole

  @admin_role_id SystemRole.role_id() |> Map.get(:admin)

  def init(opts), do: opts

  def call(conn, _opts) do

    %{ system_role_id: system_role_id } = conn.assigns[:current_author]

    case system_role_id do
      @admin_role_id -> conn
      _ -> conn
        |> resp(403, "Forbidden")
        |> halt()
    end
  end
end
