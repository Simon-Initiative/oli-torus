defmodule Oli.GenAI do
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}
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
end
