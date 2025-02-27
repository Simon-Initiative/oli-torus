defmodule OliWeb.CertificateController do
  use OliWeb, :controller

  alias Oli.Delivery.GrantedCertificates

  def index(conn, params) do
    render(conn, "index.html",
      guid: params["cert_guid"],
      recaptha_error: params["recaptcha_error"]
    )
  end

  def verify(conn, params) do
    if recaptcha_verified?(params) do
      case GrantedCertificates.get_granted_certificate_by_guid(params["guid"]["value"]) do
        c when c.state == :earned ->
          render(conn, "show.html", certificate: c)

        _ ->
          render(conn, "show.html", certificate: nil)
      end
    else
      render(conn, "index.html",
        recaptcha_error: "ReCaptcha failed, please try again",
        guid: params["guid"]["value"]
      )
    end
  end

  defp recaptcha_verified?(params) do
    recaptcha_response = Map.get(params, "g-recaptcha-response", "")
    Oli.Recaptcha.verify(recaptcha_response) == {:success, true}
  end
end
