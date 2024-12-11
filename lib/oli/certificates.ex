defmodule Oli.Certificates do
  @moduledoc """
  Module for managing granted certificates.
  """

  alias ExAws.Lambda
  alias Oli.Certificates.Certificate
  alias Oli.{HTTP, Repo}
  alias Ecto.{Multi, Changeset}

  @aws_lambda_function "generate_certificate_from_html"

  @spec create(integer(), integer(), binary()) :: {:ok, any()} | {:error, any()} | Multi.failure()
  def create(user_id, section_id, html)

  def create(_user_id, _section_id, html) when html == "", do: {:error, :invalid_html}
  def create(_user_id, _section_id, html) when not is_binary(html), do: {:error, :invalid_html}

  def create(user_id, section_id, html) do
    Multi.new()
    |> Multi.insert(
      :certificate,
      Certificate.changeset(%Certificate{}, %{
        user_id: user_id,
        section_id: section_id,
        status: "pending"
      })
    )
    |> Multi.run(:invoke_lambda, fn _repo, %{certificate: certificate} ->
      invoke_lambda(certificate.id, html)
    end)
    |> Multi.update(:complete_certificate, fn %{certificate: certificate} ->
      Changeset.change(certificate, status: "complete")
    end)
    |> Repo.transaction()
  end

  @spec get(Ecto.UUID.t()) :: %Oli.Certificates.Certificate{} | nil
  def get(certificate_id), do: Repo.get(Certificate, certificate_id)

  defp invoke_lambda(certificate_id, html) do
    @aws_lambda_function
    |> Lambda.invoke(%{certificate_id: certificate_id, html: html}, %{})
    |> request()
  end

  defp request(operation), do: apply(HTTP.aws(), :request, [operation])
end
