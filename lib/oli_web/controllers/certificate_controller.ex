defmodule OliWeb.CertificateController do
  use OliWeb, :controller

  alias Oli.Delivery.GrantedCertificates

  def index(conn, _params), do: render(conn, "index.html")

  def verify(conn, params) do
    if recaptcha_verified?(params) do
      certificate = GrantedCertificates.get_granted_certificate_by_guid(params["guid"]["value"])
      render(conn, "show.html", certificate: certificate)
    else
      render(conn, "index.html", recaptcha_error: "ReCaptcha failed, please try again")
    end
  end

  defp recaptcha_verified?(params) do
    recaptcha_response = Map.get(params, "g-recaptcha-response", "")
    Oli.Utils.Recaptcha.verify(recaptcha_response) == {:success, true}
  end
end
