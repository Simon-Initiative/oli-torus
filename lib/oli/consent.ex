defmodule Oli.Consent do
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Consent.CookiesConsent
  alias Oli.Accounts.User

  @doc """
  Creates or updates cookie consent.
  """
  def insert_cookie(name, value, expires, user_id) do
    Repo.insert!(
      %CookiesConsent{
        name: name,
        user_id: user_id,
        value: value,
        expiration: expires
      },
      on_conflict: [set: [value: value, expiration: expires]],
      conflict_target: [:name, :user_id]
    )
  end

  @doc """
  Gets a list of cookies, based on a user id.
  """
  @spec retrieve_cookies(String.t()) :: any
  def retrieve_cookies(user_id) do
    query =
      from c in CookiesConsent,
           where: c.user_id == ^user_id,
           select: c

    Repo.all(query)
  end

end
