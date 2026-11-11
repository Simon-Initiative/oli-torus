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
    |> Enum.filter(fn {_, config} -> config != nil end)
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
  Returns true if the user's email has been confirmed.
  """
  def email_confirmed?(user) do
    user.email_confirmed_at != nil
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
  Gets a user with identities.
  """
  def get_user_with_identities(user_id) do
    from(user in User,
      where: user.id == ^user_id,
      preload: [:user_identities]
    )
    |> Repo.one()
  end

  @doc """
  Creates a user with user identity.

  User schema module and repo module will be fetched from config.
  """
  def create_user_with_identity(user_identity_params, user_params) do
    changeset = User.user_identity_changeset(%User{}, user_identity_params, user_params)

    Oli.Accounts.Audited.provision_account(
      Oli.Auditing.Context.for_system(:provider_provisioning),
      {:user, nil, changeset, "sso"}
    )
  end

  @doc """
  Updates user details.
  """
  def update_user_details(user, attrs) do
    Oli.Accounts.Audited.provision_account(
      Oli.Auditing.Context.for_system(:provider_provisioning),
      {:user, user.id, &User.details_changeset(&1, attrs), "sso"}
    )
  end

  @doc """
  Adds a user identity for the provider and user.
  """
  def add_identity_provider(user, user_identity_params) do
    Oli.Accounts.Audited.link_identity(
      Oli.Auditing.Context.for_actor(user, source: :ui),
      user,
      user_identity_params
    )
  end

  @doc """
  Deletes a user identity for the provider and user.
  """
  def delete_identity_providers(
        {user_identities, rest},
        %{password_hash: password_hash} = account
      )
      when length(rest) > 0 or not is_nil(password_hash) do
    Oli.Accounts.Audited.unlink_identities(
      Oli.Auditing.Context.for_actor(account, source: :ui),
      account,
      user_identities
    )
  end

  def delete_identity_providers(_any, user) do
    changeset =
      user
      |> Changeset.change()
      |> Changeset.validate_required(:password_hash)

    {:error, {:no_password, changeset}}
  end
end
