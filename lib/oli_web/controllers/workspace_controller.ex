defmodule OliWeb.WorkspaceController do
  use OliWeb, :controller
  alias Oli.Accounts
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

  def update_live_preview_display(conn, %{"hide" => hide} = _params) do
    author = conn.assigns.current_author

    live_preview_display = if hide == "true", do: "hidden", else: "show"

    updated_preferences =
      (author.preferences || %Accounts.AuthorPreferences{})
      |> Map.put(:live_preview_display, live_preview_display)
      |> Map.from_struct()

    case Accounts.update_author(author, %{preferences: updated_preferences}) do
      {:ok, _author} ->
        conn
        |> redirect(to: Routes.workspace_path(conn, :account))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to update preview preference")
        |> redirect(to: Routes.workspace_path(conn, :account))
    end
  end

  def fetch_preferences(conn, _params) do
    author = conn.assigns.current_author

    case Accounts.get_author_by_email(author.email) do
      author ->
        conn
        |> json(author.preferences)
    end
  end

  def update_preferences(conn, preferences) do
    author = conn.assigns.current_author

    updated_preferences =
      Oli.Utils.value_or(author.preferences, %Accounts.AuthorPreferences{})
      |> Accounts.AuthorPreferences.changeset(preferences)
      |> Ecto.Changeset.apply_action!(:update)
      |> Map.from_struct()

    case Accounts.update_author(author, %{preferences: updated_preferences}) do
      {:ok, _author} ->
        conn
        |> send_resp(200, "Ok")

      {:error, _changeset} ->
        conn
        |> send_resp(500, "Failed to update preferences")
    end
  end
end
