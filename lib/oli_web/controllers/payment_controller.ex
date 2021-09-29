defmodule OliWeb.PaymentController do
  use OliWeb, :controller

  def guard(conn, %{"section_slug" => section_slug}) do
    render(conn, "guard.html", section_slug: section_slug)
  end

  def make_payment(conn, _params) do
    render(conn, "new.html")
  end

  def use_code(conn, %{"section_slug" => section_slug}) do
    render(conn, "code.html", section_slug: section_slug)
  end

  def apply_code(conn, %{
        "g-recaptcha-response" => g_recaptcha_response,
        "section_slug" => section_slug,
        "code" => %{"value" => code}
      }) do
    if recaptcha_verified?(g_recaptcha_response) do
      user = conn.assigns.current_user

      case Oli.Delivery.Paywall.redeem_code(code, user, section_slug) do
        {:ok, _} ->
          render(conn, "code_success.html", section_slug: section_slug)

        {:error, _} ->
          render(conn, "code.html", error: "This is an invalid code", section_slug: section_slug)
      end
    else
      render(conn, "code.html",
        recaptcha_error: "ReCaptcha failed, please try again",
        section_slug: section_slug
      )
    end
  end

  defp recaptcha_verified?(g_recaptcha_response) do
    g_recaptcha_response != "" and
      Oli.Utils.Recaptcha.verify(g_recaptcha_response) == {:success, true}
  end
end
