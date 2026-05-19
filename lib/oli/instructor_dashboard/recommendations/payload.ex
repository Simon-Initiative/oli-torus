defmodule Oli.InstructorDashboard.Recommendations.Payload do
  @moduledoc """
  Normalizes the public recommendation payload returned to dashboard consumers.
  """

  @allowed_metadata_keys [
    :fallback_reason,
    :prompt_version,
    :provider_usage,
    :model,
    :provider,
    :registered_model_id,
    :service_config_id
  ]

  @spec allowed_metadata_keys() :: [atom()]
  def allowed_metadata_keys, do: @allowed_metadata_keys

  @spec normalize(map()) :: map()
  def normalize(attrs) when is_map(attrs) do
    %{
      id: Map.get(attrs, :id),
      section_id: Map.get(attrs, :section_id),
      container_type: Map.get(attrs, :container_type),
      container_id: Map.get(attrs, :container_id),
      state: Map.get(attrs, :state),
      message: Map.get(attrs, :message),
      generated_at: Map.get(attrs, :generated_at),
      generation_mode: Map.get(attrs, :generation_mode),
      feedback_summary: Map.get(attrs, :feedback_summary, %{}),
      metadata: sanitize_metadata(Map.get(attrs, :metadata, %{}))
    }
  end

  @spec sanitize_metadata(map()) :: map()
  def sanitize_metadata(metadata) when is_map(metadata) do
    Enum.reduce(@allowed_metadata_keys, %{}, fn key, acc ->
      case Map.fetch(metadata, key) do
        {:ok, value} -> Map.put(acc, key, value)
        :error -> acc
      end
    end)
  end

  def sanitize_metadata(_metadata), do: %{}
end
