defmodule OliWeb.WorkspaceController do
  use OliWeb, :controller
  alias Oli.Accounts.Author

  def account(conn, _params) do
    author = conn.assigns.current_author

    render(
      conn,
      "account.html",
      title: "Account",
      active: :account,
      preferences: author.preferences,
      title: "Account",
      changeset: Author.noauth_changeset(author)
    )
  end
end
