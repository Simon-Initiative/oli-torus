defmodule Oli.Plugs.RegistrationCaptcha do
  import Plug.Conn
  alias OliWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    # plug is only applicable to registration POSTs
    register_path = Routes.pow_registration_path(conn, :create)

    author_register_path = Routes.authoring_pow_registration_path(conn, :create)

    case conn do
      %Plug.Conn{method: "POST", request_path: ^author_register_path}
      when author_register_path != nil ->
        verify_captcha(conn, :register_author)

      %Plug.Conn{method: "POST", request_path: ^register_path} when register_path != nil ->
        verify_captcha(conn, :register)

      _ ->
        conn
    end
  end

  defp verify_captcha(conn, purpose) do
    case conn.params do
      %{"g-recaptcha-response" => g_recaptcha_response} when g_recaptcha_response != "" ->
        case Oli.Utils.Recaptcha.verify(g_recaptcha_response) do
          {:success, true} ->
            conn

          {:success, false} ->
            render_captcha_error(conn, purpose)
        end

      _ ->
        render_captcha_error(conn, purpose)
    end
  end

  defp render_captcha_error(conn, :register_author) do
    conn =
      conn
      |> OliWeb.Pow.PowHelpers.use_pow_config(:author)

    changeset = Pow.Plug.change_user(conn, conn.params["user"])
    changeset = Ecto.Changeset.add_error(changeset, :captcha, "failed, please try again")

    conn
    |> OliWeb.DeliveryController.render_author_register_form(
      changeset: %{changeset | action: :insert},
      sign_in_path: Routes.authoring_pow_session_path(conn, :new),
      cancel_path: Routes.static_page_path(conn, :index)
    )
    |> halt()
  end

  defp render_captcha_error(conn, :register) do
    conn =
      conn
      |> OliWeb.Pow.PowHelpers.use_pow_config(:user)

    {:error, changeset} =
      Pow.Plug.change_user(conn, conn.params["user"])
      |> Ecto.Changeset.add_error(:captcha, "failed, please try again")
      |> Ecto.Changeset.apply_action(:insert)

    conn
    |> OliWeb.DeliveryController.render_user_register_form(changeset)
    |> halt()
  end
end
