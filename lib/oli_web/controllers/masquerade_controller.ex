defmodule OliWeb.MasqueradeController do
  use OliWeb, :new_controller

  alias Oli.Accounts

  def confirm(conn, %{"user_id" => user_id}) do
    user = Accounts.get_user!(user_id)

    render(conn, :confirm,
      user: user,
      masquerade_path: ~p"/admin/masquerade/#{user.id}",
      title: "Act as user"
    )
  end

  def masquerade(conn, %{"user_id" => user_id}) do
    user = Accounts.get_user!(user_id)

    conn
    |> put_session(:masquerading_as, user.id)
    |> put_session(:current_user_id, user.id)
    |> redirect(to: ~p"/sections")
  end

  def unmasquerade(conn, _) do
    conn
    |> delete_session(:masquerading_as)
    |> delete_session(:current_user_id)
    |> redirect(to: ~p"/")
  end
end
