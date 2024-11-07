defmodule Oli.AssentAuth.UserAssentAuth do
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Ecto.Changeset
  alias Oli.AssentAuth
  alias Oli.AssentAuth.UserIdentity
  alias Oli.Accounts.User

  @behaviour AssentAuth

  @doc """
  Returns a list of configured authentication providers.
  """
  def authentication_providers() do
    Application.get_env(:oli, :user_auth_providers)
  end

  @doc """
  Fetches the configuration for the given provider.
  """
  def provider_config!(provider) do
    Application.get_env(:oli, :user_auth_providers)[provider] ||
      raise "No provider configuration for #{provider}"
  end

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

  @doc """
  Upserts a user identity.

  If a matching user identity already exists for the user, the identity will be updated,
  otherwise a new identity is inserted.
  """
  def upsert(user, user_identity_params) do
    {uid_provider_params, additional_params} =
      Map.split(user_identity_params, ["uid", "provider"])

    get_user_identity(uid_provider_params["provider"], uid_provider_params["uid"])
    |> case do
      nil -> insert_identity(user, user_identity_params)
      identity -> update_identity(identity, additional_params)
    end
  end

  @doc """
  Inserts a user identity for the user.
  """
  def insert_identity(user, user_identity_params) do
    user_identity = Ecto.build_assoc(user, :user_identities)

    user_identity
    |> user_identity.__struct__.changeset(user_identity_params)
    |> Repo.insert()
  end

  @doc """
  Updates a user identity.
  """
  def update_identity(user_identity, additional_params) do
    user_identity
    |> user_identity.__struct__.changeset(additional_params)
    |> Repo.insert()
  end

  @doc """
  Creates a user with user identity.

  User schema module and repo module will be fetched from config.
  """
  def create_user_with_identity(user_identity_params, user_params) do
    %User{}
    |> User.user_identity_changeset(user_identity_params, user_params)
    |> Repo.insert()
  end

  @doc """
  Gets a user by identity provider and uid.
  """
  def get_user_by_provider_uid(provider, uid) do
    from(user in User,
      join: user_identity in assoc(user, :user_identities),
      where: user_identity.provider == ^provider and user_identity.uid == ^uid
    )
    |> Repo.one()
  end

  @doc """
  Gets a user identity by provider and uid.
  """
  def get_user_identity(provider, uid) do
    from(u in UserIdentity,
      where: u.provider == ^provider and u.uid == ^uid
    )
    |> Repo.one()
  end

  def get_user_with_identities(user_id) do
    from(user in User,
      where: user.id == ^user_id,
      preload: [:user_identities]
    )
    |> Repo.one()
  end

  @doc """
  Deletes a user identity for the provider and user.
  """
  def delete_identity_providers(
        {user_identities, rest},
        %{password_hash: password_hash}
      )
      when length(rest) > 0 or not is_nil(password_hash) do
    results =
      from(uid in UserIdentity,
        where: uid.id in ^Enum.map(user_identities, & &1.id)
      )
      |> Repo.delete_all()

    {:ok, results}
  end

  def delete_identity_providers(_any, user) do
    changeset =
      user
      |> Changeset.change()
      |> Changeset.validate_required(:password_hash)

    {:error, {:no_password, changeset}}
  end
end
