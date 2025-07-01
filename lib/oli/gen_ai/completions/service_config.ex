defmodule Oli.GenAI.Completions.ServiceConfig do
  use Ecto.Schema

  import Ecto.Changeset

  schema "completions_service_configs" do
    field :name, :string
    field :primary_model, references(:registered_models)
    field :backup_model, references(:registered_models)
    field :temperature, :float, null: true
    field :max_tokens, :integer, null: true
  end

  def changeset(service_config, attrs) do
    service_config
    |> cast(attrs, [:name, :primary_model, :backup_model, :temperature, :max_tokens])
    |> validate_required([:name, :primary_model, :backup_model, :temperature, :max_tokens])
  end

end
