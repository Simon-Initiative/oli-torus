defmodule Oli.Lti_1p3.LoginHints do
  require Logger

  # login_hints only persist for a day
  # 86400 seconds = 24 hours
  @max_login_hint_ttl_sec 86_400

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Lti_1p3.LoginHint

  @doc """
  Gets a single login_hint by value
  Returns nil if the LoginHint does not exist.
  ## Examples
      iex> get_login_hint(123)
      %LoginHint{}
      iex> get_login_hint(456)
      nil
  """
  def get_login_hint_by_value(value), do: Repo.get_by(LoginHint, value: value)

  @doc """
  Creates a login_hint for a user.
  Raises an error if the creation fails
  ## Examples
      iex> create_login_hint!(session_user_id)
      %LoginHint{}
  """
  def create_login_hint!(session_user_id, context \\ nil) do
    %LoginHint{}
    |> LoginHint.changeset(%{value: UUID.uuid4(), session_user_id: session_user_id, context: context})
    |> Repo.insert!()
  end

  @doc """
  Removes all login_hints older than the configured @max_login_hint_ttl_sec value
  """
  def cleanup_login_hint_store() do
    Logger.info("Cleaning up expired LTI 1.3 login_hints...")

    login_hint_expiry = Timex.now |> Timex.subtract(Timex.Duration.from_seconds(@max_login_hint_ttl_sec))
    result = Repo.delete_all from(n in LoginHint, where: n.inserted_at < ^login_hint_expiry)

    Logger.info("Login_hint cleanup complete.")

    result
  end

end
