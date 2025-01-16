defmodule Oli.Delivery.GrantedCertificates do
  @moduledoc """
  The Granted Certificates context
  """

  alias Ecto.Changeset
  alias ExAws.Lambda
  alias Oli.Delivery.Sections.GrantedCertificate
  alias Oli.{HTTP, Repo}

  # TODO: Change once we know where we'll generate the granted certificate HTML
  @certificate_html ""

  @generate_pdf_lambda_function "generate_certificate_pdf_from_html"

  def generate_pdf(granted_certificate_id) do
    case Repo.get(GrantedCertificate, granted_certificate_id) do
      nil ->
        {:error, :granted_certificate_not_found}

      %GrantedCertificate{url: url} when not is_nil(url) ->
        {:error, :granted_certificate_already_has_url}

      gc ->
        @generate_pdf_lambda_function
        |> Lambda.invoke(%{certificate_id: gc.guid, html: @certificate_html}, %{})
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

  defp aws_request(operation), do: apply(HTTP.aws(), :request, [operation])
end
