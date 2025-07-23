defmodule Oli.GenAI.Completions.ServiceConfig do
  use Ecto.Schema

  import Ecto.Changeset

  schema "completions_service_configs" do
    field :name, :string
    belongs_to :primary_model, Oli.GenAI.Completions.RegisteredModel
    belongs_to :backup_model, Oli.GenAI.Completions.RegisteredModel
    field :temperature, :float, default: nil
    field :max_tokens, :integer, default: nil

    timestamps(type: :utc_datetime)
  end

  def changeset(service_config, attrs) do
    service_config
    |> cast(attrs, [:name, :primary_model_id, :backup_model_id, :temperature, :max_tokens])
    |> validate_required([:name, :primary_model_id, :backup_model_id, :temperature, :max_tokens])
  end

end
