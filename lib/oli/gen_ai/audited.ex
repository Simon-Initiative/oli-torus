defmodule Oli.GenAI.Audited do
  @moduledoc """
  Application boundary for audited AI service configuration: registered models, service
  configurations, and feature configurations (including per-section overrides).

  Each command records `ai_service_settings_changed` in the same transaction as the change.
  Provider API keys are recorded only as redaction markers. Commands do not authorize the
  actor; callers keep their existing authorization.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  alias Ecto.Multi
  alias Oli.Auditing.{Command, Context}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}
  alias Oli.GenAI.FeatureConfig

  @type kind :: :registered_model | :service_config | :feature_config

  @doc "Creates a configuration of `kind` and records its settings."
  @spec create(Context.t(), kind(), map()) :: {:ok, struct()} | {:error, term()}
  def create(context, kind, attrs),
    do: Command.run(:config, &create_multi(&1, :config, context, {kind, attrs}))

  @doc "Adds the steps of `create/3` to `multi`, for callers that own the transaction."
  @spec create_multi(Multi.t(), Multi.name(), Context.t(), {kind(), map()}) :: Multi.t()
  def create_multi(multi, name, context, {kind, attrs}) do
    schema = schema(kind)
    Command.insert(multi, name, context, schema.changeset(struct(schema), attrs), spec(kind))
  end

  @doc "Updates the configuration of `kind` with ID `id` and records the settings that changed."
  @spec update(Context.t(), kind(), pos_integer(), map()) :: {:ok, struct()} | {:error, term()}
  def update(context, kind, id, attrs) do
    schema = schema(kind)

    Command.run(:config, fn multi ->
      Command.update(
        multi,
        :config,
        context,
        {schema, id},
        &schema.changeset(&1, attrs),
        spec(kind)
      )
    end)
  end

  @doc """
  Deletes the configuration of `kind` with ID `id` and records the deletion. A configuration
  still in use (for example a service configuration that feature configurations reference)
  returns `{:error, :delete_failed}`.
  """
  @spec delete(Context.t(), kind(), pos_integer()) :: {:ok, struct()} | {:error, term()}
  def delete(context, kind, id) do
    Command.run(:config, &Command.delete(&1, :config, context, {schema(kind), id}, spec(kind)))
  end

  defp spec(kind) do
    %{
      event_type: :ai_service_settings_changed,
      policy: Fields.ai_service(),
      proposal: fn config, operation ->
        %{
          entity:
            {:ai_service, "#{kind}:#{config.id}", %{id: config.id, label: label(kind, config)}},
          scope: scope(config),
          event_key: "ai_service:#{kind}:#{config.id}:#{operation}"
        }
      end
    }
  end

  defp scope(%FeatureConfig{section_id: section_id}) when is_integer(section_id),
    do: %{section_id: section_id}

  defp scope(_config), do: %{}

  defp label(:feature_config, config), do: "Feature #{config.feature}"
  defp label(_kind, config), do: config.name

  defp schema(:registered_model), do: RegisteredModel
  defp schema(:service_config), do: ServiceConfig
  defp schema(:feature_config), do: FeatureConfig
end
