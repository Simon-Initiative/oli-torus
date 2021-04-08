defmodule Oli.Plugs.MaybeEnrollOpenAndFreeUser do
  import Plug.Conn
  import Phoenix.Controller
  import Oli.Utils

  alias Oli.Delivery.Sections
  alias OliWeb.Router.Helpers, as: Routes
  alias Lti_1p3.Tool.ContextRoles

  def init(opts), do: opts

  def call(conn, _opts) do
    with %{"section_slug" => section_slug} <- conn.path_params,
         {:ok, section} <-
           Sections.get_section_by(slug: section_slug, open_and_free: true) |> trap_nil do
      case Pow.Plug.current_user(conn) do
        nil ->
          conn
          |> redirect(
            to:
              Routes.delivery_path(conn, :new_user,
                redirect_to: "/#{Enum.join(conn.path_info, "/")}"
              )
          )
          |> halt()

        user ->
          maybe_enroll_user(conn, user, section)
      end
    else
      _ ->
        conn
    end
  end

  defp maybe_enroll_user(conn, user, section) do
    if Sections.is_enrolled?(user.id, section.slug) do
      # user is already enrolled
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
          |> Phoenix.Controller.put_flash(:info, "Welcome to Open and Free!")
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
