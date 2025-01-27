defmodule Oli.Delivery.Certificates do
  @moduledoc """
  The Certificates context
  """

  alias Oli.Delivery.Sections.Certificate
  alias Oli.Repo

  @doc """
  Creates a certificate.

  ## Examples
      iex> create(%{field: value})
      {:ok, %Certificate{}}

      iex> create(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create(attrs) do
    attrs |> Certificate.changeset() |> Repo.insert()
  end

  @doc """
  Retrieves a certificate by the id.

  ## Examples
  iex> get_certificate(1)
  %Certificate{}

  iex> get_certificate(123)
  nil
  """
  def get_certificate(certificate_id), do: Repo.get(Certificate, certificate_id)
end
