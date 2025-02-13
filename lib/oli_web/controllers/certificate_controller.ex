defmodule OliWeb.CertificateController do
  use OliWeb, :controller

  alias Oli.Delivery.GrantedCertificates

  def index(conn, _params), do: render(conn, "index.html")

  def verify(conn, params) do
    if recaptcha_verified?(params) do
      case GrantedCertificates.get_granted_certificate_by_guid(params["guid"]["value"]) do
        c when c.state == :earned ->
          render(conn, "show.html", certificate: c, certificate_url: s3_certificate_url(c))

        _ ->
          render(conn, "show.html", certificate: nil)
      end
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
