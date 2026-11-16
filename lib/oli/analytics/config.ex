defmodule Oli.Analytics.Config do
  @moduledoc "Runtime configuration for the optional Google Tag Manager installation."

  @doc """
  Loads and validates GTM settings. Blank or absent container IDs disable analytics.

  An enabled container requires every GA4 measurement ID in
  `GOOGLE_ANALYTICS_MEASUREMENT_IDS`, a comma-separated list, so tracking can be
  disabled immediately when consent is withdrawn even if browser cookies are blocked.
  """
  @spec load_from_env!((String.t() -> String.t() | nil)) :: keyword()
  def load_from_env!(get_env \\ &System.get_env/1) do
    case value(get_env, "GOOGLE_TAG_MANAGER_ID") do
      nil ->
        [gtm_container_id: nil]

      container_id ->
        validate!(container_id, ~r/\AGTM-[A-Z0-9]+\z/, "GOOGLE_TAG_MANAGER_ID")
        measurement_ids = measurement_ids!(get_env)
        auth = value(get_env, "GOOGLE_TAG_MANAGER_AUTH")
        preview = value(get_env, "GOOGLE_TAG_MANAGER_PREVIEW")

        case {auth, preview} do
          {nil, nil} ->
            :ok

          {auth, preview} when is_binary(auth) and is_binary(preview) ->
            validate!(auth, ~r/\A[A-Za-z0-9_-]+\z/, "GOOGLE_TAG_MANAGER_AUTH")
            validate!(preview, ~r/\Aenv-[0-9]+\z/, "GOOGLE_TAG_MANAGER_PREVIEW")

          _ ->
            raise ArgumentError,
                  "GOOGLE_TAG_MANAGER_AUTH and GOOGLE_TAG_MANAGER_PREVIEW must be set together"
        end

        [
          gtm_container_id: container_id,
          gtm_auth: auth,
          gtm_preview: preview,
          measurement_ids: measurement_ids
        ]
    end
  end

  defp measurement_ids!(get_env) do
    case value(get_env, "GOOGLE_ANALYTICS_MEASUREMENT_IDS") do
      nil ->
        raise ArgumentError,
              "GOOGLE_ANALYTICS_MEASUREMENT_IDS must include at least one GA4 measurement ID when GOOGLE_TAG_MANAGER_ID is set"

      ids ->
        ids
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(fn id ->
          validate!(id, ~r/\AG-[A-Z0-9]+\z/, "GOOGLE_ANALYTICS_MEASUREMENT_IDS")
          id
        end)
        |> Enum.uniq()
    end
  end

  defp value(get_env, key) do
    case get_env.(key) do
      nil ->
        nil

      value ->
        case String.trim(value) do
          "" -> nil
          value -> value
        end
    end
  end

  defp validate!(value, pattern, key) do
    case Regex.match?(pattern, value) do
      true -> :ok
      false -> raise ArgumentError, "Invalid #{key} format"
    end
  end
end
