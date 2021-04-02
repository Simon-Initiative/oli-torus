defmodule Oli.Plugs.MaybeEnrollOpenAndFreeUser do
  import Plug.Conn
  import Phoenix.Controller
  import Oli.Utils

  alias Oli.Delivery.Sections
  alias Oli.Accounts
  alias OliWeb.Common.LtiSession
  alias OliWeb.Router.Helpers, as: Routes
  alias Lti_1p3.Tool.ContextRoles

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = maybe_login_user_param(conn)

    with %{"section_slug" => section_slug} <- conn.path_params,
         {:ok, section} <- Sections.get_section_by(slug: section_slug, open_and_free: true) |> trap_nil
    do
      case Pow.Plug.current_user(conn) do
        nil ->
          conn
          |> redirect(to: Routes.delivery_path(conn, :new_user, redirect_to: "/#{Enum.join(conn.path_info, "/")}"))
          |> halt()
        user ->
          maybe_enroll_user(conn, user, section)
      end
    else
      _ ->
        conn
    end
  end

  defp maybe_login_user_param(conn) do
    case conn.query_params do
      %{"user" => sub} ->
        with user when not is_nil(user) <- Accounts.get_user_by(sub: sub)
        do
          conn
          |> LtiSession.put_user_params(user.sub)
          |> OliWeb.Pow.PowHelpers.use_pow_config(:user)
          |> Pow.Plug.create(user)
          |> redirect(to: "/#{Enum.join(conn.path_info, "/")}")
          |> halt()
        else
          _ ->
            conn
        end

      _ ->
        conn
    end
  end

  defp maybe_enroll_user(conn, user, section) do
    if Sections.is_enrolled?(user.id, section.slug) do
      # user is already enrolled
      conn
    else
      # enroll new open and free user in this section as a student/learner
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn
      |> Phoenix.Controller.put_flash(:info, "Welcome to Open and Free! Save this URL to login: #{Routes.page_delivery_url(conn, :index, section.slug)}?user=#{user.sub}")
    end
  end

end
