defmodule OliWeb.AuthAssent do
  use OliWeb, :verified_routes

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.UserIdentities.UserIdentity

  @doc """
  Fetches all user identities for user.
  """
  def list_user_identities(user) do
    from(uid in UserIdentity,
      where: uid.user_id == ^user.id
    )
    |> Repo.all()
  end

  @doc """
  Returns true if the user has a password set up.
  """
  def has_password?(user) do
    user.password_hash != nil
  end
end
