defmodule OliWeb.CertificateController do
  use OliWeb, :controller

  alias Oli.Delivery.GrantedCertificates

  def index(conn, _params), do: render(conn, "index.html")

  def verify(conn, params) do
    if recaptcha_verified?(params) do
      certificate = GrantedCertificates.get_granted_certificate_by_guid(params["guid"]["value"])
      certificate_url = s3_certificate_url(certificate)
      render(conn, "show.html", certificate: certificate, certificate_url: certificate_url)
    else
      render(conn, "index.html", recaptcha_error: "ReCaptcha failed, please try again")
    end
  end

  defp recaptcha_verified?(params) do
    recaptcha_response = Map.get(params, "g-recaptcha-response", "")
    Oli.Utils.Recaptcha.verify(recaptcha_response) == {:success, true}
  end

  defp s3_certificate_url(%{guid: guid}),
    do: "https://torus-pdf-certificates.s3.amazonaws.com/certificates/#{guid}.pdf"

  defp s3_certificate_url(_), do: nil
end
