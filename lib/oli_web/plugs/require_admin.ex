defmodule Oli.Plugs.RequireAdmin do
  import Plug.Conn
  alias Oli.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    if Accounts.has_admin_role?(conn.assigns[:current_author]) do
      conn
    else
      conn
      |> resp(403, "Forbidden")
      |> halt()
    end
  end

  def reject_content_admin(conn, _opts) do
    if Accounts.is_content_admin?(conn.assigns[:current_author]) do
      conn
      |> resp(403, "Forbidden")
      |> halt()
    else
      conn
    end
  end

  def reject_content_or_account_admin(conn, _opts) do
    if Accounts.is_content_admin?(conn.assigns[:current_author]) ||
         Accounts.is_account_admin?(conn.assigns[:current_author]) do
      conn
      |> resp(403, "Forbidden")
      |> halt()
    else
      conn
    end
  end
end
