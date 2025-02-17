defmodule Oli.Delivery.Sections.Certificates.Workers.GeneratePdf do
  use Oban.Worker, queue: :certificate_pdf, max_attempts: 3

  alias Oli.Delivery.GrantedCertificates

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"granted_certificate_id" => granted_certificate_id}}) do
    GrantedCertificates.generate_pdf(granted_certificate_id)
    |> case do
      {:error, error_type, error} ->
        {:error, "Error: #{error_type} #{inspect(error)}"}

      {:ok, granted_certificate} ->
        {:ok, granted_certificate}
    end
  end
end
