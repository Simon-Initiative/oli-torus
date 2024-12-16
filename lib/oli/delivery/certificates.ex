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
end
