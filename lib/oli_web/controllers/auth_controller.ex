defmodule OliWeb.AuthController do
  use OliWeb, :controller
  plug Ueberauth

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Accounts.SystemRole
  alias Oli.Repo

  def signin(conn, _params) do
    actions = %{
      google: Routes.auth_path(conn, :request, "google"),
      facebook: Routes.auth_path(conn, :request, "facebook"),
      identity: Routes.auth_path(conn, :identity_callback),
    }
    render(conn, "signin.html", title: "Sign In", actions: actions, show_remember_password: true, show_cancel: false)
  end

  def signout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: Routes.static_page_path(conn, :index))
  end

  def register(conn, _params) do
    actions = %{
      google: Routes.auth_path(conn, :request, "google"),
      facebook: Routes.auth_path(conn, :request, "facebook"),
      identity: Routes.auth_path(conn, :register_email_form),
    }
    render(conn, "register.html", title: "Create an Account", actions: actions)
  end

  def register_email_form(conn, %{"type" => "link-account"}) do
    actions = %{
      submit: Routes.auth_path(conn, :register_email_submit, type: "link-account"),
      cancel: Routes.delivery_path(conn, :index)
    }
    changeset = Author.changeset(%Author{})
    render conn, "register_email.html", changeset: changeset, actions: actions
  end

  def register_email_form(conn, _params) do
    actions = %{
      submit: Routes.auth_path(conn, :register_email_submit),
      cancel: Routes.auth_path(conn, :register)
    }
    changeset = Author.changeset(%Author{})
    render conn, "register_email.html", changeset: changeset, actions: actions
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
    } = params)
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
        case params do
          %{"type" => "link-account"} ->
            link_account_callback(conn, author)
          _ ->
            signin_callback(conn, author)
        end

      {:error, changeset} ->
        # remove password_hash from changeset for security, just in case
        changeset = Ecto.Changeset.delete_change(changeset, :password_hash)
        actions = %{
          submit: Routes.auth_path(conn, :register_email_submit),
          cancel: Routes.auth_path(conn, :register)
        }
        conn
        |> render("register_email.html", changeset: changeset, actions: actions)
    end
  end

  def callback(%Elixir.Plug.Conn{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: Routes.auth_path(conn, :signin))
  end

  def callback(%Elixir.Plug.Conn{assigns: %{ueberauth_auth: auth}} = conn, params) do
    author_params = case auth.provider do
      :google ->
        %{
          email: auth.info.email,
          first_name: auth.info.first_name,
          last_name: auth.info.last_name,
          provider: "google",
          token: auth.credentials.token,
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
        }
    end

    case Accounts.insert_or_update_author(author_params) do
      {:ok, author} ->
        case params do
          %{"type" => "link-account"} ->
            link_account_callback(conn, author)
          _ ->
            signin_callback(conn, author)
        end

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error signing in")
        |> redirect(to: Routes.auth_path(conn, :signin))
    end
  end

  def identity_callback(%{assigns: %{ueberauth_auth: auth}} = conn, params) do
    %Ueberauth.Auth{
      info: %{
        email: email,
      },
      credentials: %{
        other: %{
          password: password,
        }
      }
    } = auth;

    # emails are case-insensitive, use lowercased version
    email = String.downcase(email)

    case Accounts.authorize_author(email, password) do
      { :ok, author } ->
        case params do
          %{"type" => "link-account"} ->
            link_account_callback(conn, author)
          _ ->
            signin_callback(conn, author)
        end
      { :error, reason } ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: Routes.auth_path(conn, :signin))
    end
  end

  def signin_callback(conn, author) do
    conn
    |> put_session(:current_author_id, author.id)
    |> redirect(to: redirect_path(conn, author))
  end

  def link_account_callback(conn, author) do
    case Accounts.link_user_author_account(conn.assigns.current_user, author) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Account '#{author.email}' is now linked")
        |> put_session(:current_author_id, author.id)
        |> redirect(to: Routes.delivery_path(conn, :index))
      _ ->
        throw "Failed to link user and author accounts"
    end
  end

  # redirect to project overview if author has one project, else go to workspace
  defp redirect_path conn, author do
    author = Repo.preload(author, [:projects])

    case length author.projects do
      1 -> Routes.project_path conn, :overview, (hd author.projects).slug
      _ -> Routes.live_path OliWeb.Endpoint, OliWeb.Projects.ProjectsLive
    end
  end

end
