defmodule Oli.Analytics.Config do
  @moduledoc "Runtime configuration for the optional Google Tag Manager installation."

  @doc "Loads and validates GTM settings. Blank or absent container IDs disable analytics."
  @spec load_from_env!((String.t() -> String.t() | nil)) :: keyword()
  def load_from_env!(get_env \\ &System.get_env/1) do
    case value(get_env, "GOOGLE_TAG_MANAGER_ID") do
      nil ->
        [gtm_container_id: nil]

      container_id ->
        validate!(container_id, ~r/\AGTM-[A-Z0-9]+\z/, "GOOGLE_TAG_MANAGER_ID")
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

        [gtm_container_id: container_id, gtm_auth: auth, gtm_preview: preview]
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
