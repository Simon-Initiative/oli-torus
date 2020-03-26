defmodule OliWeb.AuthController do
  use OliWeb, :controller
  plug Ueberauth

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Accounts.SystemRole
  alias Oli.Repo

  def signin(conn, _params) do
    render(conn, "signin.html")
  end

  def signout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: Routes.page_path(conn, :index))
  end

  def register(conn, _params) do
    render(conn, "register.html")
  end

  def register_email_form(conn, _params) do
    changeset = Author.changeset(%Author{})
    render conn, "register_email.html", changeset: changeset
  end

  def register_email_submit(
    conn,
    %{
      "author" => %{
        "email" => email,
        "first_name" => first_name,
        "last_name" => last_name,
        "password" => password,
        "password_confirmation" => password_confirmation
      },
    })
  do
    author_params = %{
      email: email,
      first_name: first_name,
      last_name: last_name,
      provider: "identity",
      password: password,
      password_confirmation: password_confirmation,
      email_verified: false,
      system_role_id: SystemRole.role_id.author
    }

    case Accounts.create_author(author_params) do
      {:ok, author} ->
        conn
        |> put_session(:current_author_id, author.id)
        |> redirect(to: Routes.workspace_path(conn, :projects))

      {:error, changeset} ->
        # remove password_hash from changeset for security, just in case
        changeset = Ecto.Changeset.delete_change(changeset, :password_hash)
        conn
        |> render("register_email.html", changeset: changeset)
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: Routes.auth_path(conn, :signin))
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    author_params = case auth.provider do
      :google ->
        %{
          email: auth.info.email,
          first_name: auth.info.first_name,
          last_name: auth.info.last_name,
          provider: "google",
          token: auth.credentials.token,
          system_role_id: SystemRole.role_id.author
        }
      :facebook ->
        # FIXME: There has to be a better way to get first_name and last_name from facebook
        # Changing OAuth scope params resulted in error, for now we will try to infer from full name
        [first_name, last_name] = String.split(auth.info.name, " ")
        %{
          email: auth.info.email,
          first_name: first_name,
          last_name: last_name,
          provider: "facebook",
          token: auth.credentials.token,
          system_role_id: SystemRole.role_id.author
        }
    end

    case Accounts.insert_or_update_author(author_params) do
      {:ok, author} ->
        conn
        |> put_session(:current_author_id, author.id)
        |> redirect(to: (redirect_path conn, author))

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error signing in")
        |> redirect(to: Routes.auth_path(conn, :signin))
    end
  end

  def identity_callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    %Ueberauth.Auth{
      info: %{email: email},
      credentials: %{other: %{password: password}}
    } = auth

    # emails are case-insensitive, use lowercased version
    email = String.downcase(email)

    case Accounts.authorize_author(email, password) do
      { :ok, author } ->
        conn
        |> put_session(:current_author_id, author.id)
        |> redirect(to: (redirect_path conn, author))
      { :error, reason } ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: Routes.auth_path(conn, :signin))
    end
  end

  # redirect to project overview if author has one project, else go to workspace
  defp redirect_path conn, author do
    author = Repo.preload(author, [:projects])

    case length author.projects do
      1 -> Routes.project_path conn, :overview, hd author.projects
      _ -> Routes.workspace_path conn, :projects
    end
  end

end
