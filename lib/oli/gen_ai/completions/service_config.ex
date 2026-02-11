defmodule Oli.GenAI.Completions.ServiceConfig do
  use Ecto.Schema

  import Ecto.Changeset

  schema "completions_service_configs" do
    field :name, :string
    belongs_to :primary_model, Oli.GenAI.Completions.RegisteredModel
    belongs_to :secondary_model, Oli.GenAI.Completions.RegisteredModel
    belongs_to :backup_model, Oli.GenAI.Completions.RegisteredModel

    field :usage_count, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  def changeset(service_config, attrs) do
    service_config
    |> cast(attrs, [
      :name,
      :primary_model_id,
      :secondary_model_id,
      :backup_model_id
    ])
    |> validate_required([
      :name,
      :primary_model_id
    ])
    |> validate_secondary_model()
  end

  defp validate_secondary_model(changeset) do
    primary_id = get_field(changeset, :primary_model_id)
    secondary_id = get_field(changeset, :secondary_model_id)
    backup_id = get_field(changeset, :backup_model_id)

    cond do
      is_nil(secondary_id) ->
        changeset

      secondary_id == primary_id ->
        add_error(changeset, :secondary_model_id, "must be different from primary model")

      not is_nil(backup_id) and secondary_id == backup_id ->
        add_error(changeset, :secondary_model_id, "must be different from backup model")

      true ->
        changeset
    end
  end
end
