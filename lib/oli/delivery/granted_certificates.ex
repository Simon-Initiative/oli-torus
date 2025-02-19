defmodule Oli.Delivery.GrantedCertificates do
  @moduledoc """
  The Granted Certificates context
  """

  alias Ecto.Changeset
  alias ExAws.Lambda
  alias Oli.Delivery.Sections.Certificates.Workers.{GeneratePdf, Mailer}
  alias Oli.Delivery.Sections.GrantedCertificate
  alias Oli.Delivery.Certificates.CertificateRenderer
  alias Oli.{HTTP, Repo}

  @doc """
  Returns the granted certificate with the given guid.
  """
  def get_granted_certificate_by_guid(guid) do
    Repo.get_by(GrantedCertificate, guid: guid)
  end

  @doc """
  Generates a .pdf for the granted certificate with the given id by invoking a lambda function.
  The granted certificate must exist and not have a url already.
  """
  def generate_pdf(granted_certificate_id) do
    case Repo.get(GrantedCertificate, granted_certificate_id) do
      nil ->
        {:error, :granted_certificate_not_found}

      gc ->
        gc.guid
        |> invoke_lambda(CertificateRenderer.render(gc))
        |> case do
          {:error, error} ->
            {:error, :invoke_lambda_error, error}

          {:ok, result} ->
            if result["statusCode"] == 200 do
              gc
              |> Changeset.change(url: certificate_s3_url(gc.guid))
              |> Repo.update()
            else
              {:error, :error_generating_pdf, result}
            end
        end
    end
  end

  @doc """
  Updates a granted certificate with the given attributes.
  This update does not trigger the generation of a .pdf.
  (we use it, for example, to invalidate a granted certificate by updating its state to :denied)

  If in the future we have some cases where we need to update the granted certificate and generate a .pdf
  we should create another function or extend this one with a third argument to indicate if we should do so
  """
  def update_granted_certificate(granted_certificate_id, attrs) do
    Repo.get(GrantedCertificate, granted_certificate_id)
    |> GrantedCertificate.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a new granted certificate and schedules a job to generate the .pdf
  if the certificate has an :earned state.
  """
  def create_granted_certificate(attrs) do
    attrs = Map.merge(attrs, %{issued_at: DateTime.utc_now()})

    %GrantedCertificate{}
    |> GrantedCertificate.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, %{state: :earned, id: id} = granted_certificate} ->
        # This oban job will create the pdf and update the granted_certificate.url
        # only for certificates with the :earned state (:denied ones do not need a .pdf)
        GeneratePdf.new(%{granted_certificate_id: id})
        |> Oban.insert()

        {:ok, granted_certificate}

      {:ok, granted_certificate} ->
        {:ok, granted_certificate}

      error ->
        error
    end
  end

  def send_email(granted_certificate, to, template) do
    # TODO finish implementation with MER-4107
    Mailer.new(%{granted_certificate_id: granted_certificate.id, to: to, template: template})
    |> Oban.insert()
  end

  defp certificate_s3_url(guid) do
    s3_pdf_bucket = Application.fetch_env!(:oli, :certificates)[:s3_pdf_bucket]
    "https://#{s3_pdf_bucket}.s3.amazonaws.com/certificates/#{guid}.pdf"
  end

  defp invoke_lambda(guid, html) do
    :oli
    |> Application.fetch_env!(:certificates)
    |> Keyword.fetch!(:generate_pdf_lambda)
    |> Lambda.invoke(%{certificate_id: guid, html: html}, %{})
    |> HTTP.aws().request()
  end
end
