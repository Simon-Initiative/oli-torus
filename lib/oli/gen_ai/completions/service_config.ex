defmodule Oli.GenAI.Completions.ServiceConfig do
  use Ecto.Schema

  import Ecto.Changeset

  schema "completions_service_configs" do
    field :name, :string
    belongs_to :primary_model, Oli.GenAI.Completions.RegisteredModel
    belongs_to :secondary_model, Oli.GenAI.Completions.RegisteredModel
    belongs_to :backup_model, Oli.GenAI.Completions.RegisteredModel

    field :primary_pool_capacity, :integer, default: 100
    field :secondary_pool_capacity, :integer, default: 100
    field :backup_pool_capacity, :integer, default: 100
    field :required_capabilities, {:array, :string}, default: []

    field :usage_count, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc "Validates tier selections and positive transport capacities; Provider membership is checked in the GenAI context."
  def changeset(service_config, attrs) do
    service_config
    |> cast(attrs, [
      :name,
      :primary_pool_capacity,
      :secondary_pool_capacity,
      :backup_pool_capacity,
      :required_capabilities,
      :primary_model_id,
      :secondary_model_id,
      :backup_model_id
    ])
    |> validate_required([
      :name,
      :primary_model_id,
      :primary_pool_capacity,
      :secondary_pool_capacity,
      :backup_pool_capacity
    ])
    |> foreign_key_constraint(:primary_model_id)
    |> foreign_key_constraint(:secondary_model_id)
    |> foreign_key_constraint(:backup_model_id)
    |> validate_blank_capacities(attrs)
    |> validate_capability_array()
    |> validate_secondary_model()
    |> validate_number(:primary_pool_capacity, greater_than: 0)
    |> validate_number(:secondary_pool_capacity, greater_than: 0)
    |> validate_number(:backup_pool_capacity, greater_than: 0)
    |> check_constraint(:primary_pool_capacity, name: :primary_pool_capacity_positive)
    |> check_constraint(:secondary_pool_capacity, name: :secondary_pool_capacity_positive)
    |> check_constraint(:backup_pool_capacity, name: :backup_pool_capacity_positive)
  end

  defp validate_blank_capacities(changeset, attrs) do
    Enum.reduce(
      [:primary_pool_capacity, :secondary_pool_capacity, :backup_pool_capacity],
      changeset,
      fn field, cs ->
        case Map.get(attrs, field, Map.get(attrs, Atom.to_string(field))) do
          "" -> add_error(cs, field, "can't be blank")
          _ -> cs
        end
      end
    )
  end

  defp validate_capability_array(changeset) do
    case get_field(changeset, :required_capabilities) do
      nil -> add_error(changeset, :required_capabilities, "must be a list")
      _ -> changeset
    end
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
