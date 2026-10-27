defmodule Oli.Consent do
  import Ecto.Query, warn: false

  alias Oli.Accounts.User
  alias Oli.Consent.CookiesConsent
  alias Oli.Repo

  @version 2
  @choices_cookie "_cky_opt_choices"
  @defaults %{
    "necessary" => true,
    "functionality" => true,
    "analytics" => false,
    "targeting" => false,
    "version" => nil
  }

  @doc "Returns the consent policy version requiring an explicit analytics decision."
  @spec version() :: pos_integer()
  def version, do: @version

  @doc "Resolves preferences using the signed-in user's stored choice before browser cookies."
  @spec preferences(Plug.Conn.t()) :: map()
  def preferences(conn) do
    case conn.assigns[:current_user] do
      %{id: user_id} -> preferences_for_user(user_id) || browser_preferences(conn)
      _ -> browser_preferences(conn)
    end
  end

  @doc "Returns the Google analytics storage state for the resolved current-version decision."
  @spec analytics_consent(Plug.Conn.t()) :: String.t()
  def analytics_consent(conn) do
    case preferences(conn)["analytics"] do
      true -> "granted"
      _ -> "denied"
    end
  end

  @doc "Returns normalized stored preferences, or nil when no choice exists for this user."
  @spec preferences_for_user(integer()) :: map() | nil
  def preferences_for_user(user_id) do
    case choices_for_user(user_id) do
      nil -> nil
      cookie -> normalize_cookie(cookie)
    end
  end

  @doc "Normalizes JSON or map preferences, preserving functional consent when analytics needs re-consent."
  @spec normalize_preferences(term()) :: map()
  def normalize_preferences(value) when is_binary(value) do
    case decode_preferences(value) do
      {:ok, preferences} -> normalize_preferences(preferences)
      _ -> @defaults
    end
  end

  def normalize_preferences(value) when is_map(value) do
    current? = current_decision?(value)

    version =
      case current? do
        true -> @version
        false -> nil
      end

    %{
      @defaults
      | "functionality" => boolean_or_default(value["functionality"], true),
        "analytics" => current? and value["analytics"] == true,
        "version" => version
    }
  end

  def normalize_preferences(_), do: @defaults

  @doc "Checks for a valid explicit analytics decision under the current consent policy."
  @spec current_decision?(term()) :: boolean()
  def current_decision?(value) when is_binary(value) do
    case decode_preferences(value) do
      {:ok, preferences} -> current_decision?(preferences)
      _ -> false
    end
  end

  def current_decision?(%{"version" => @version, "analytics" => analytics})
      when is_boolean(analytics),
      do: true

  def current_decision?(_), do: false

  @doc "Copies browser preferences at login only when they improve on the stored consent version."
  @spec sync_preferences(integer(), term()) :: :ok
  def sync_preferences(user_id, browser_value) do
    stored = choices_for_user(user_id)

    case {decode_preferences(browser_value), stored} do
      {{:ok, browser}, nil} ->
        persist_login_preferences(user_id, browser)

      {{:ok, browser}, %CookiesConsent{} = cookie} ->
        case current_decision?(browser) and not current_decision?(normalize_cookie(cookie)) do
          true -> persist_login_preferences(user_id, browser)
          false -> :ok
        end

      _ ->
        :ok
    end
  end

  @doc """
  Persists validated consent cookies atomically, ignoring older decisions from the same page.

  Optional decision metadata is stored only in the database choices value. Locking the
  user also serializes concurrent first writes, before a consent cookie row exists.
  """
  @spec persist_preferences(
          [map()],
          integer(),
          %{group: String.t(), sequence: pos_integer()} | nil
        ) ::
          {:ok, :persisted | :superseded} | {:error, term()}
  def persist_preferences(cookies, user_id, decision \\ nil) do
    Repo.transaction(fn ->
      Repo.one!(
        from user in User, where: user.id == ^user_id, select: user.id, lock: "FOR UPDATE"
      )

      case superseded_decision?(choices_for_user(user_id), decision) do
        true ->
          :superseded

        false ->
          Enum.each(cookies, fn cookie ->
            value = with_decision_metadata(cookie, decision)
            insert_cookie(cookie.name, value, cookie.expiration, user_id)
          end)

          :persisted
      end
    end)
  end

  @doc """
  Creates or updates cookie consent.
  """
  def insert_cookie(name, value, expires, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.insert!(
      %CookiesConsent{
        name: name,
        user_id: user_id,
        value: value,
        expiration: expires
      },
      on_conflict: [set: [value: value, expiration: expires, updated_at: now]],
      conflict_target: [:name, :user_id]
    )
  end

  @doc """
  Gets a list of cookies, based on a user id.
  """
  @spec retrieve_cookies(integer()) :: [%CookiesConsent{}]
  def retrieve_cookies(user_id) do
    query =
      from c in CookiesConsent,
        where: c.user_id == ^user_id,
        select: c

    Repo.all(query)
  end

  defp choices_for_user(user_id) do
    Repo.get_by(CookiesConsent, name: @choices_cookie, user_id: user_id)
  end

  defp normalize_cookie(cookie) do
    preferences = normalize_preferences(cookie.value)

    case DateTime.compare(cookie.expiration, DateTime.utc_now()) do
      :gt -> preferences
      _ -> %{preferences | "analytics" => false, "version" => nil}
    end
  end

  defp browser_preferences(conn) do
    case conn.cookies do
      %Plug.Conn.Unfetched{} -> @defaults
      cookies -> normalize_preferences(cookies[@choices_cookie])
    end
  end

  defp boolean_or_default(value, _default) when is_boolean(value), do: value
  defp boolean_or_default(_, default), do: default

  defp decode_preferences(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, preferences} when is_map(preferences) ->
        {:ok, preferences}

      _ ->
        case Jason.decode(URI.decode(value)) do
          {:ok, preferences} when is_map(preferences) -> {:ok, preferences}
          _ -> :error
        end
    end
  rescue
    ArgumentError -> :error
  end

  defp decode_preferences(_), do: :error

  defp superseded_decision?(%CookiesConsent{value: value}, %{group: group, sequence: sequence}) do
    case decode_preferences(value) do
      {:ok, %{"_decision_group" => ^group, "_decision_sequence" => stored_sequence}}
      when is_integer(stored_sequence) and sequence <= stored_sequence ->
        true

      _ ->
        false
    end
  end

  defp superseded_decision?(_, _), do: false

  defp with_decision_metadata(%{name: @choices_cookie, value: value}, %{
         group: group,
         sequence: sequence
       }) do
    value
    |> normalize_preferences()
    |> Map.merge(%{"_decision_group" => group, "_decision_sequence" => sequence})
    |> Jason.encode!()
  end

  defp with_decision_metadata(cookie, _), do: cookie.value

  defp persist_login_preferences(user_id, preferences) do
    expiration = DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second)

    # Preserve legacy version metadata so login cannot turn implied consent into an explicit decision.
    value = preferences |> normalize_preferences() |> Jason.encode!()
    insert_cookie(@choices_cookie, value, expiration, user_id)
    :ok
  end
end
