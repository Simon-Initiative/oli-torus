defmodule Oli.GenAI.Completions.RegisteredModel do
  use Ecto.Schema

  import Ecto.Changeset

  schema "registered_models" do
    field :name, :string
    field :provider, Ecto.Enum, values: [:null, :open_ai, :claude]
    field :model, :string
    field :url_template, :string
    field :api_key_variable_name, :string
    field :secondary_api_key_variable_name, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(registered_model, attrs) do
    registered_model
    |> cast(attrs, [
      :name,
      :provider,
      :model,
      :url_template,
      :api_key_variable_name,
      :secondary_api_key_variable_name
    ])
    |> validate_required([
      :name,
      :provider,
      :model,
      :url_template,
      :api_key_variable_name,
      :secondary_api_key_variable_name
    ])
  end
end
