defmodule Oli.Plugs.MaybeEnrollOpenAndFreeUser do
  import Oli.Utils
  alias Oli.Delivery.Sections
  alias Oli.Accounts
  alias OliWeb.Common.LtiSession
  alias OliWeb.Router.Helpers, as: Routes
  alias Lti_1p3.Tool.PlatformRoles

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = maybe_login_user_param(conn)

    with %{"section_slug" => section_slug} <- conn.path_params,
         {:ok, section} <- Sections.get_section_by(slug: section_slug, open_and_free: true) |> trap_nil
    do
      case Pow.Plug.current_user(conn) do
        nil ->
          case create_open_and_free_user() do
            {:ok, user} ->
              maybe_enroll_user(conn, user, section)

            _ ->
              throw "Error creating open and free user"
          end
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
          |> Phoenix.Controller.redirect(to: "/#{Enum.join(conn.path_info, "/")}")
        else
          _ ->
            conn
        end

      _ ->
        conn
    end
  end

  defp create_open_and_free_user() do
    {:ok, user} = Accounts.create_user(%{
      # generate a unique sub identifier which is also used so a user can access
      # their progress in the future or using a different browser
      sub: UUID.uuid4(),
    })

    # TODO: consider removing
    Accounts.update_user_platform_roles(user, [
      PlatformRoles.get_role(:institution_learner),
    ])
  end

  defp maybe_enroll_user(conn, user, section) do
    if Sections.is_enrolled?(user.id, section.slug) do
      # user is already enrolled
      conn
    else
      # TODO: consider changing, open and free has no concept of LTI roles
      # enroll new open and free user in this section as a student/learner
      context_roles = [
        Lti_1p3.Tool.ContextRoles.get_role(:context_learner),
      ]

      Sections.enroll(user.id, section.id, context_roles)

      conn
      |> Phoenix.Controller.put_flash(:info, "Welcome to Open and Free! Save this URL to login: #{Routes.page_delivery_url(conn, :index, section.slug)}?user=#{user.sub}")
    end
    |> OliWeb.Pow.PowHelpers.use_pow_config(:user)
    |> Pow.Plug.create(user)
  end

end
