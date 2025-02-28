defmodule Oli.Delivery.Sections.Certificates.Workers.GeneratePdf do
  @moduledoc """
  Worker to generate a .pdf for a granted certificate.
  This will call a lambda function to create it. The same function will update the Granted Certificate with the url to that pdf.

  The "send_email?" arg is to conditionally send an email to the student after the pdf is generated.

  """

  use Oban.Worker, queue: :certificate_pdf, max_attempts: 3

  alias Oli.Delivery.GrantedCertificates

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"granted_certificate_id" => granted_certificate_id, "send_email?" => send_email}
      }) do
    GrantedCertificates.generate_pdf(granted_certificate_id)
    |> case do
      {:error, error_type, error} ->
        {:error, "Error: #{error_type} #{inspect(error)}"}

      {:ok, granted_certificate} ->
        if send_email do
          # TODO: MER-4107.
          # we need to provide the target email as an arg of the oban job,
          # or delegate that responsability to the Mailer Worker (grab the email by joining GrantedCertificate with User)
          student_email = "dummy@email.com"

          GrantedCertificates.send_certificate_email(
            granted_certificate.id,
            student_email,
            :certificate_approval
          )
        end

        {:ok, granted_certificate}
    end
  end
end
