defmodule OliWeb.Pow.AuthorControllerCallbacks do
  @moduledoc """
  Custom module to add callbacks to the authoring pow controllers to do some light pre/post-processing of the request,
  for example, to link the just created authoring account to the user account that is currently in the conn.
  More info in https://hexdocs.pm/pow/1.0.31/README.html#phoenix-controllers
  """
  use Pow.Extension.Phoenix.ControllerCallbacks.Base
  use OliWeb, :verified_routes

  alias Oli.Utils
  alias OliWeb.Pow.SessionUtils
  alias OliWeb.Router.Helpers, as: Routes

  def before_respond(
        Pow.Phoenix.SessionController,
        :create,
        {:error, %Plug.Conn{assigns: %{request_path: "/workspaces/course_author"}} = conn},
        _config
      ) do
    conn
    |> Phoenix.Controller.put_flash(:error, messages(conn).invalid_credentials(conn))
    |> Phoenix.Controller.redirect(to: ~p"/workspaces/course_author")
  end

  def before_respond(
        Pow.Phoenix.SessionController,
        :create,
        {:ok,
         %Plug.Conn{
           assigns: %{request_path: "/workspaces/course_author", ctx: %{user: %{author_id: nil}}}
         } = conn},
        _config
      ) do
    {:ok, _updated_user} =
      link_to_user_account(conn.assigns.current_user, conn.assigns.current_author.id)

    conn
    |> maybe_logout_user()
    |> Phoenix.Controller.put_flash(
      :info,
      "Account '#{conn.assigns.current_author.email}' is now linked to '#{conn.assigns.current_user.email}'"
    )
    |> Phoenix.Controller.redirect(to: ~p"/workspaces/course_author")
  end

  def before_respond(
        Pow.Phoenix.SessionController,
        :create,
        {:ok, conn},
        _config
      ) do
    {:ok, maybe_logout_user(conn)}
  end

  def before_respond(
        Pow.Phoenix.RegistrationController,
        :create,
        {:error, author_changeset, conn},
        _config
      ) do
    # for security reasons (possible account information leakage)
    # we don't want to show the email "has already been taken" error message (see MER-3129)
    already_taken_email = author_changeset.changes[:email]
    updated_errors = Keyword.delete(author_changeset.errors, :email)

    conn =
      if updated_errors == [] and already_taken_email do
        Oli.Email.create_email(
          already_taken_email,
          "Account already exists",
          "account_already_exists.html",
          %{
            url:
              Utils.ensure_absolute_url(Routes.authoring_pow_session_path(OliWeb.Endpoint, :new)),
            forgot_password:
              Utils.ensure_absolute_url(
                Routes.authoring_pow_reset_password_reset_password_path(OliWeb.Endpoint, :new)
              )
          }
        )
        |> Oli.Mailer.deliver_now()

        conn
        |> Phoenix.Controller.put_flash(
          :info,
          """
          To continue, check #{already_taken_email} for a confirmation email.\n
          If you don’t receive this email, check your Spam folder or verify that #{already_taken_email} is correct.\n
          You can close this tab if you received the email.
          """
        )
      else
        conn
      end

    {:error, %{author_changeset | errors: updated_errors}, conn}
  end

  def before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, author, conn}, _config) do
    conn = maybe_assign_request_path(conn)

    case conn do
      %{query_params: %{"link_to_user_account?" => "true"}, assigns: %{ctx: %{user: user}}}
      when not is_nil(user) ->
        {:ok, _updated_user} = link_to_user_account(user, author.id)

        {:ok, author, conn}

      _ ->
        {:ok, author, conn}
    end
  end

  _docp = """
  If there is a "request_path" query parameter in the request, assign it to the conn.
  And since we are assigning that path to the conn, that means we are going to be redirected to that path after the action is performed.
  See OliWeb.Pow.AuthorRoutes.after_sign_in_path/1 and OliWeb.Pow.AuthorRoutes.after_registration_path/1
  """

  defp maybe_assign_request_path(
         %Plug.Conn{query_params: %{"request_path" => request_path}} = conn
       )
       when request_path not in ["", nil] do
    Plug.Conn.assign(conn, :request_path, request_path)
  end

  defp maybe_assign_request_path(conn), do: conn

  defp link_to_user_account(user_account, author_id),
    do: OliWeb.Pow.UserContext.update(user_account, %{author_id: author_id})

  defp maybe_logout_user(conn) do
    if conn.assigns.current_user != nil and
         Oli.Accounts.is_system_admin?(conn.assigns.current_author) do
      SessionUtils.perform_signout(conn, "user")
    else
      conn
    end
  end
end
