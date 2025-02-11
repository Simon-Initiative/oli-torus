defmodule Oli.Delivery.GrantedCertificates do
  @moduledoc """
  The Granted Certificates context
  """

  alias Ecto.Changeset
  alias ExAws.Lambda
  alias Oli.Delivery.Sections.GrantedCertificate
  alias Oli.Delivery.Certificates.CertificateRenderer
  alias Oli.{HTTP, Repo}

  @generate_pdf_lambda_function "generate_certificate_pdf_from_html"

  def get_granted_certificate_by_guid(guid) do
    Repo.get_by(GrantedCertificate, guid: guid)
  end

  def generate_pdf(granted_certificate_id) do
    case Repo.get(GrantedCertificate, granted_certificate_id) do
      nil ->
        {:error, :granted_certificate_not_found}

      %GrantedCertificate{url: url} when not is_nil(url) ->
        {:error, :granted_certificate_already_has_url}

      %GrantedCertificate{state: state} when state != :earned ->
        {:error, :granted_certificate_is_not_earned}

      gc ->
        certificate_html = generate_html(gc)

        @generate_pdf_lambda_function
        |> Lambda.invoke(%{certificate_id: gc.guid, html: certificate_html}, %{})
        |> aws_request()
        |> case do
          {:error, error} ->
            {:error, :invoke_lambda_error, error}

          {:ok, result} ->
            if result["statusCode"] == 200 do
              gc
              |> Changeset.change(url: result["body"]["s3Path"])
              |> Repo.update()
            else
              {:error, :error_generating_pdf, result}
            end
        end
    end
  end

  def generate_html(granted_certificate) do
    granted_certificate = Repo.preload(granted_certificate, [:certificate, :user])

    certificate_type =
      if granted_certificate.with_distinction,
        do: "Certificate with Distinction",
        else: "Certificate of Completion"

    admin_fields =
      Map.take(granted_certificate.certificate, [
        :admin_name1,
        :admin_title1,
        :admin_name2,
        :admin_title2,
        :admin_name3,
        :admin_title3
      ])

    admins =
      [
        {admin_fields.admin_name1, admin_fields.admin_title1},
        {admin_fields.admin_name2, admin_fields.admin_title2},
        {admin_fields.admin_name3, admin_fields.admin_title3}
      ]
      |> Enum.reject(fn {name, _} -> name == "" || !name end)

    logos =
      Map.take(granted_certificate.certificate, [:logo1, :logo2, :logo3])
      |> Enum.reject(fn {name, _} -> name == "" || !name end)

    attrs = %{
      certificate_type: certificate_type,
      student_name: granted_certificate.user.name,
      completion_date:
        granted_certificate.issued_at |> DateTime.to_date() |> Calendar.strftime("%B %d, %Y"),
      certificate_id: granted_certificate.guid,
      course_name: granted_certificate.certificate.title,
      course_description: granted_certificate.certificate.description,
      administrators: admins,
      logos: logos
    }

    CertificateRenderer.render(attrs)
  end

  defp aws_request(operation), do: apply(HTTP.aws(), :request, [operation])
end
