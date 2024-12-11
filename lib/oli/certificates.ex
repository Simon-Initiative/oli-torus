defmodule Oli.Certificates do
  @moduledoc """
  Module for managing granted certificates.
  """

  alias ExAws.Lambda
  alias Oli.Certificates.Certificate
  alias Oli.{HTTP, Repo}

  @aws_lambda_function "generate_certificate_from_html"

  @spec create(integer(), integer(), binary()) :: {:ok, binary()} | {:error, term()}
  def create(user_id, section_id, html)

  def create(_user_id, _section_id, html) when html == "", do: {:error, :invalid_html}
  def create(_user_id, _section_id, html) when not is_binary(html), do: {:error, :invalid_html}

  def create(user_id, section_id, html) do
    case generate(html) do
      {:ok, certificate_url} ->
        store(user_id, section_id, certificate_url)

      error ->
        error
    end
  end

  @spec get(Ecto.UUID.t()) :: %Oli.Certificates.Certificate{} | nil
  def get(certificate_id), do: Repo.get(Certificate, certificate_id)

  defp generate(html) do
    @aws_lambda_function
    |> Lambda.invoke(%{html: html}, %{})
    |> request()
  end

  defp store(user_id, section_id, certificate_url) do
    %Certificate{}
    |> Certificate.changeset(%{
      user_id: user_id,
      section_id: section_id,
      certificate_url: certificate_url
    })
    |> Repo.insert()
  end

  defp request(operation) do
    HTTP.aws()
    |> apply(:request, [operation])
    |> case do
      {:ok, %{body: %{certificate_url: certificate_url}}} -> {:ok, certificate_url}
      other -> {:error, other}
    end
  end
end
