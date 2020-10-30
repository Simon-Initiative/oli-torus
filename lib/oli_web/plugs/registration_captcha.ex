defmodule Oli.Plugs.RegistrationCaptcha do
  import Plug.Conn
  alias OliWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    # plug is only applicable to registration POSTs
    register_path = Routes.pow_registration_path(conn, :create)
    register_and_link_provider_path = case conn do
      %{params: %{"provider" => provider}} ->
        Routes.pow_assent_registration_path(conn, :create, provider)
      _ ->
        nil
    end
    register_and_link_user_path = Routes.delivery_path(conn, :process_create_and_link_account_user)

    case conn do
      %Plug.Conn{method: "POST", request_path: ^register_path} when register_path != nil ->
        verify_captcha(conn, :register)
      %Plug.Conn{method: "POST", request_path: ^register_and_link_provider_path} when register_and_link_provider_path != nil ->
        verify_captcha(conn, :create_and_link_account)
      %Plug.Conn{method: "POST", request_path: ^register_and_link_user_path} when register_and_link_user_path != nil ->
        verify_captcha(conn, :create_and_link_account)
      _ ->
        conn
    end
  end

  defp verify_captcha(conn, purpose) do
    case conn.params do
      %{"g-recaptcha-response" => g_recaptcha_response} when g_recaptcha_response != "" ->
        case Oli.Utils.Recaptcha.verify(g_recaptcha_response) do
          {:success, :true} ->
            conn

          {:success, :false} ->
            render_captcha_error(conn, purpose)
        end
      _ ->
        render_captcha_error(conn, purpose)
    end
  end

  defp render_captcha_error(conn, purpose) do
    conn = conn
      |> OliWeb.Pow.PowHelpers.use_pow_config(:author)

    changeset = Pow.Plug.change_user(conn, conn.params["user"])
    changeset = Ecto.Changeset.add_error(changeset, :captcha, "failed, please try again")

    case purpose do
      :register ->
        conn
        |> OliWeb.DeliveryController.render_create_and_link_form(
          changeset: %{changeset | action: :insert},
          sign_in_path: Routes.pow_session_path(conn, :new),
          cancel_path: Routes.static_page_path(conn, :index)
        )
        |> halt()

      :create_and_link_account ->
        conn
        |> OliWeb.DeliveryController.render_create_and_link_form(
          changeset: %{changeset | action: :insert}
        )
        |> halt()
    end

  end

end
