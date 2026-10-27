defmodule OliWeb.CookieConsentController do
  use OliWeb, :controller

  alias Oli.Consent

  @doc "Persists validated consent cookies for the authenticated user."
  def persist_cookies(conn, params) do
    case conn.assigns[:current_user] do
      nil ->
        json(conn, %{"result" => "success", "info" => "user not found"})

      user ->
        with {:ok, cookies} <- validate_cookies(params["cookies"]),
             {:ok, decision} <- validate_decision(Map.fetch(params, "decision")),
             {:ok, _} <- Consent.persist_preferences(cookies, user.id, decision) do
          json(conn, %{"result" => "success", "info" => "cookies persisted"})
        else
          _ ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{"result" => "error", "info" => "invalid cookie preferences"})
        end
    end
  end

  @doc "Returns unexpired consent cookies belonging to the authenticated user."
  def retrieve(conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        json(conn, %{"result" => "no-op"})

      user ->
        cookies =
          user.id
          |> Consent.retrieve_cookies()
          |> Enum.filter(&(DateTime.compare(&1.expiration, DateTime.utc_now()) == :gt))
          |> Enum.map(&public_cookie/1)

        json(conn, cookies)
    end
  end

  defp validate_cookies(cookies) when is_list(cookies) and length(cookies) in 1..2 do
    Enum.reduce_while(cookies, {:ok, []}, fn cookie, {:ok, validated} ->
      case validate_cookie(cookie) do
        {:ok, cookie} -> {:cont, {:ok, [cookie | validated]}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp validate_cookies(_), do: :error

  defp validate_decision(:error), do: {:ok, nil}

  defp validate_decision({:ok, %{"group" => group, "sequence" => sequence}})
       when is_binary(group) and is_integer(sequence) and sequence > 0 and
              sequence <= 9_007_199_254_740_991 do
    case Regex.match?(~r/\A[a-f0-9]{32}\z/, group) do
      true -> {:ok, %{group: group, sequence: sequence}}
      false -> :error
    end
  end

  defp validate_decision(_), do: :error

  defp validate_cookie(%{"name" => name, "value" => value, "expiresIso" => expires})
       when is_binary(value) and is_binary(expires) do
    with {:ok, value} <- validate_value(name, value),
         {:ok, expiration, _offset} <- DateTime.from_iso8601(expires),
         :gt <- DateTime.compare(expiration, DateTime.utc_now()) do
      maximum = DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second)
      expiration = Enum.min([expiration, maximum], DateTime) |> DateTime.truncate(:second)
      {:ok, %{name: name, value: value, expiration: expiration}}
    else
      _ -> :error
    end
  end

  defp validate_cookie(_), do: :error

  defp validate_value("_cky_opt_choices", value) do
    case Consent.current_decision?(value) do
      true -> {:ok, value |> Consent.normalize_preferences() |> Jason.encode!()}
      false -> :error
    end
  end

  defp validate_value("_cky_opt_in", value) when value in ["true", "false"], do: {:ok, value}
  defp validate_value(_, _), do: :error

  defp public_cookie(%{name: "_cky_opt_choices"} = cookie),
    do: %{cookie | value: cookie.value |> Consent.normalize_preferences() |> Jason.encode!()}

  defp public_cookie(cookie), do: cookie
end
