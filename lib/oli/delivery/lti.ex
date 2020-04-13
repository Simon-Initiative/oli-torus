defmodule Oli.Delivery.Lti do
  @moduledoc """
  The Lti context.
  """

  # nonces only persist for a day
  @max_nonce_ttl_sec 86_400

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Delivery.Lti.Nonce

  def list_nonce_store do
    Repo.all(Nonce)
  end

  def get_nonce!(id), do: Repo.get!(Nonce, id)

  def create_nonce(attrs \\ %{}) do
    %Nonce{}
    |> Nonce.changeset(attrs)
    |> Repo.insert()
  end

  def update_nonce(%Nonce{} = nonce, attrs) do
    nonce
    |> Nonce.changeset(attrs)
    |> Repo.update()
  end

  def delete_nonce(%Nonce{} = nonce) do
    Repo.delete(nonce)
  end

  def change_nonce(%Nonce{} = nonce) do
    Nonce.changeset(nonce, %{})
  end

  def cleanup_nonce_store() do
    # delete all nonces older than configured @max_nonce_ttl_sec
    nonce_expiry = DateTime.add(DateTime.utc_now(), -1 * @max_nonce_ttl_sec, :second)
    from(n in Nonce, where: n.inserted_at < ^nonce_expiry)
    |> Repo.delete_all
  end

  def parse_lti_role(roles) do
    cond do
      String.contains?(roles, "Administrator") ->
        :administrator
      String.contains?(roles, "Instructor") ->
        :instructor
      String.contains?(roles, "Learner") ->
        :student
    end
  end

end
