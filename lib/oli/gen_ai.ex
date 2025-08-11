defmodule Oli.GenAI do
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}
  alias Oli.GenAI.FeatureConfig
  alias Oli.Repo

  import Ecto.Query, warn: false

  @doc """
  Returns a list of all registered GenAI models.
  """
  def registered_models do
    query =
      from r in RegisteredModel,
        order_by: r.id,
        select_merge: %{
          service_config_count:
            fragment(
              "(SELECT count(*) FROM completions_service_configs sc
                WHERE sc.primary_model_id = ? OR sc.backup_model_id = ?)",
              r.id,
              r.id
            )
        }

    Repo.all(query)
  end

  def delete_registered_model(%RegisteredModel{} = registered_model) do
    Repo.delete(registered_model)
  end

  def update_registered_model(%RegisteredModel{} = registered_model, attrs) do
    registered_model
    |> RegisteredModel.changeset(attrs)
    |> Repo.update()
  end

  def create_registered_model(attrs) do
    %RegisteredModel{}
    |> RegisteredModel.changeset(attrs)
    |> Repo.insert()
  end

  def service_configs do
    query =
      from r in ServiceConfig,
        order_by: r.id,
        preload: [:primary_model, :backup_model],
        select_merge: %{
          usage_count:
            fragment(
              "(SELECT count(*) FROM gen_ai_feature_configs fc
                WHERE fc.service_config_id = ?)",
              r.id
            )
        }

    Repo.all(query)
  end

  def delete_service_config(%ServiceConfig{} = service_config) do
    Repo.delete(service_config)
  end

  def update_service_config(%ServiceConfig{} = service_config, attrs) do
    service_config
    |> ServiceConfig.changeset(attrs)
    |> Repo.update()
  end

  def create_service_config(attrs) do
    %ServiceConfig{}
    |> ServiceConfig.changeset(attrs)
    |> Repo.insert()
  end

  def feature_config_exists?(feature, section_id) do
    from(
      g in FeatureConfig,
      where: g.section_id == ^section_id and g.feature == ^feature
    )
    |> Oli.Repo.exists?()
  end

  def feature_configs do
    query =
      from r in FeatureConfig,
        order_by: r.id,
        preload: [:service_config, :section]

    Repo.all(query)
  end

  def delete_feature_config(%FeatureConfig{} = feature_config) do
    Repo.delete(feature_config)
  end

  def update_feature_config(%FeatureConfig{} = feature_config, attrs) do
    feature_config
    |> FeatureConfig.changeset(attrs)
    |> Repo.update()
  end

  def create_feature_config(attrs) do
    %FeatureConfig{}
    |> FeatureConfig.changeset(attrs)
    |> Repo.insert()
  end
end
