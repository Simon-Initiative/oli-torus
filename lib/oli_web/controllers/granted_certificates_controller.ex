defmodule OliWeb.GrantedCertificatesController do
  use OliWeb, :controller

  alias Oli.Analytics.DataTables.DataTable
  alias OliWeb.Common.Utils

  @doc """
  Download granted certificates in CSV format.
  It only considers certificates that are in the earned state.

  Since we are querying a product, this will include all certificates granted
  by all courses created based on that product.
  """
  def download_granted_certificates(conn, params) do
    data =
      Oli.Delivery.Certificates.get_granted_certificates_by_section_id(params["product_id"],
        filter_by_state: [:earned]
      )
      |> Enum.reduce([], fn %{recipient: recipient, issuer: issuer} = gc, acc ->
        record = %{
          student_name: Utils.name(recipient.name, recipient.family_name, recipient.given_name),
          student_email: gc.recipient.email,
          issued_at: gc.issued_at,
          issuer_name: Utils.name(issuer.name, issuer.family_name, issuer.given_name),
          guid: gc.guid
        }

        [record | acc]
      end)
      |> Enum.reverse()

    contents =
      data
      |> DataTable.new()
      |> DataTable.headers([:student_name, :student_email, :issued_at, :issuer_name, :guid])
      |> DataTable.to_csv_content()

    conn
    |> send_download({:binary, contents},
      filename: "#{params["product_id"]}_granted_certificates_content.csv"
    )
  end
end
