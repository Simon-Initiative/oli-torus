defmodule Oli.Delivery.GrantedCertificates do
  @moduledoc """
  The Granted Certificates context
  """

  import Ecto.Query, warn: false

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

  @doc """
  Sends an email to the given email address with the given template, to inform the student
  about the status of the granted certificate.
  """
  def send_certificate_email(granted_certificate_id, to, template) do
    # TODO: check on MER-4107 if we need to add more assign fields to the email,
    # and if the granted_certificate is updated to mark the student_email_sent field as true
    Mailer.new(%{granted_certificate_id: granted_certificate_id, to: to, template: template})
    |> Oban.insert()
  end

  @doc """
  Fetches all the students that have a granted certificate in the given section with status :earned or :denied,
  and sends them an email with the corresponding template (if they have not been sent yet).
  """
  def bulk_send_certificate_status_email(section_slug) do
    # TODO: check on MER-4107 if we need to add more assign fields to the email,
    # and if the granted_certificate is updated to mark the student_email_sent field as true

    granted_certificates =
      Repo.all(
        from gc in GrantedCertificate,
          join: cert in assoc(gc, :certificate),
          join: s in assoc(cert, :section),
          join: student in assoc(gc, :user),
          where: s.slug == ^section_slug,
          where: gc.state in [:earned, :denied],
          where: gc.student_email_sent == false,
          select: {gc.id, gc.state, student.email}
      )

    granted_certificates
    |> Enum.map(fn {id, state, email} ->
      Mailer.new(%{
        granted_certificate_id: id,
        to: email,
        template: if(state == :earned, do: :certificate_approval, else: :certificate_denial)
      })
    end)
    |> Oban.insert_all()
  end

  @doc """
  Counts the number of granted certificates in the given section that have not been emailed to the students yet.
  (that have the student_email_sent field set to false).
  This count won't include students that haven't yet acomplished the certificate (there is no GrantedCertificate record).
  """
  def certificate_pending_email_notification_count(section_slug) do
    Repo.one(
      from gc in GrantedCertificate,
        join: cert in assoc(gc, :certificate),
        join: s in assoc(cert, :section),
        where: gc.state in [:earned, :denied],
        where: s.slug == ^section_slug,
        where: gc.student_email_sent == false,
        select: count(gc.id)
    )
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
