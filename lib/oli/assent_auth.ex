defmodule Oli.AssentAuth do
  @moduledoc """
  AssentAuth behaviour required by AuthAssentWeb module for persistence related to assent authentication.
  """

  @doc """
  Returns a list of configured authentication providers.
  """
  @callback authentication_providers() :: keyword()

  @doc """
  Fetches the configuration for the given provider.
  """
  @callback provider_config!(Atom.t()) :: keyword()

  @doc """
  Fetches all user identities for user.
  """
  @callback list_user_identities(Atom.t()) :: [String.t()]

  @doc """
  Returns true if the user has a password set up.
  """
  @callback has_password?(any()) :: boolean()

  @doc """
  Returns true if the user's email has been confirmed.
  """
  @callback email_confirmed?(any()) :: boolean()

  @doc """
  Upserts a user identity.

  If a matching user identity already exists for the user, the identity will be updated,
  otherwise a new identity is inserted.
  """
  @callback upsert_identity(Atom.t(), map()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Creates a user with user identity.

  User schema module and repo module will be fetched from config.
  """
  @callback create_user_with_identity(any(), map()) :: {:ok, any()} | {:error, any()}

  @doc """
  Updates user details.
  """
  @callback update_user_details(any(), map()) :: {:ok, any()} | {:error, any()}

  @doc """
  Gets a user by identity provider and uid.
  """
  @callback get_user_by_provider_uid(String.t(), String.t()) :: any()

  @doc """
  Gets a user with identities.
  """
  @callback get_user_with_identities(integer()) :: any()

  @doc """
  Deletes a user identity for the provider and user.
  """
  @callback delete_identity_providers({[any()], [any()]}, any()) :: {:ok, any()} | {:error, any()}
end
