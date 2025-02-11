defmodule OliWeb.CertificateController do
  use OliWeb, :controller

  alias Oli.Delivery.GrantedCertificates
  alias Oli.Repo

  def show(conn, %{"guid" => guid}) do
    case GrantedCertificates.get_granted_certificate_by_guid(guid) do
      nil ->
        send_resp(conn, 404, "Not Found")

      gc ->
        granted_certificate = Repo.preload(gc, [:certificate, :user])
        render(conn, "show.html", certificate: granted_certificate)
    end
  end
end
