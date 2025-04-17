defmodule Oli.Delivery.Sections.Certificates.Workers.GeneratePdf do
  @moduledoc """
  Worker to generate a .pdf for a granted certificate.
  This will call a lambda function to create it. The same function will update the Granted Certificate with the url to that pdf.

  The "send_email?" arg is to conditionally send an email to the student after the pdf is generated.

  """

  use Oban.Worker, queue: :certificate_pdf, max_attempts: 3
  use OliWeb, :verified_routes

  alias Oli.Delivery.GrantedCertificates
  alias Oli.Repo

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
          granted_certificate =
            Repo.preload(granted_certificate, [
              :user,
              certificate: [
                section: [:brand, lti_1p3_deployment: [institution: [:default_brand]]]
              ]
            ])

          section = granted_certificate.certificate.section

          GrantedCertificates.send_certificate_email(
            granted_certificate.guid,
            granted_certificate.user.email,
            "student_approval",
            %{
              student_name: OliWeb.Common.Utils.name(granted_certificate.user),
              course_name: section.title,
              certificate_link:
                Phoenix.VerifiedRoutes.url(
                  OliWeb.Endpoint,
                  ~p"/sections/#{section.slug}/certificate/#{granted_certificate.guid}"
                ),
              platform_name: Oli.Branding.brand_name(section)
            }
          )
        end

        {:ok, granted_certificate}
    end
  end
end
