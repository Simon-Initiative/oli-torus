defmodule Oli.Plugs.MaybeEnrollOpenAndFreeUser do
  import Plug.Conn
  import Phoenix.Controller
  import Oli.Utils

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Router.Helpers, as: Routes
  alias Lti_1p3.Tool.ContextRoles

  def init(opts), do: opts

  def call(conn, _opts) do
    with %{"section_slug" => section_slug} <- conn.path_params,
         {:ok, section} <-
           Sections.get_section_by(slug: section_slug, open_and_free: true) |> trap_nil,
         user <- Pow.Plug.current_user(conn) do
      conn
      |> handle_user_for_section(user, section)
      |> maybe_enroll_user(user, section)
    else
      _ ->
        conn
    end
  end

  # Sections that require_enrollment disallow guest users
  defp handle_user_for_section(conn, user, %Section{requires_enrollment: true}) do
    if is_nil(user) or Accounts.user_is_guest?(conn) do
      require_signin(conn)
    else
      conn
    end
  end

  defp handle_user_for_section(conn, user, %Section{} = section) do
    if is_nil(user) do
      conn
      |> redirect(to: Routes.delivery_path(conn, :enroll, section.slug))
      |> halt()
    else
      conn
    end
  end

  defp require_signin(conn) do
    conn
    |> redirect(to: Routes.pow_session_path(conn, :new))
    |> halt()
  end

  defp maybe_enroll_user(conn, user, section) do
    if conn.halted or Sections.is_enrolled?(user.id, section.slug) do
      conn
    else
      now = Timex.now()

      cond do
        section.registration_open != true ->
          conn
          |> section_unavailable(:registration_closed)

        not is_nil(section.start_date) and Timex.before?(now, section.start_date) ->
          conn
          |> section_unavailable(:before_start_date)

        not is_nil(section.end_date) and Timex.after?(now, section.end_date) ->
          conn
          |> section_unavailable(:after_end_date)

        true ->
          # enroll new open and free user in this section as a student/learner
          Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

          conn
      end
    end
  end

  defp section_unavailable(conn, reason) do
    conn
    |> put_view(OliWeb.DeliveryView)
    |> put_status(403)
    |> render("section_unavailable.html", reason: reason)
    |> halt()
  end
end
