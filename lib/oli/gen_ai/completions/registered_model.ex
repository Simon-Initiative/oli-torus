defmodule Oli.GenAI.Completions.RegisteredModel do
  use Ecto.Schema

  import Ecto.Changeset

  schema "registered_models" do
    field :name, :string
    field :provider, Ecto.Enum, values: [:null, :open_ai, :claude]
    field :model, :string
    field :url_template, :string
    field :api_key, Oli.Encrypted.Binary
    field :secondary_api_key, Oli.Encrypted.Binary
    field :timeout, :integer, default: 8000
    field :recv_timeout, :integer, default: 60000

    # virtual field for count of service configs appearing in
    field :service_config_count, :integer, virtual: true

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
      :api_key,
      :secondary_api_key,
      :timeout,
      :recv_timeout
    ])
    |> validate_required([
      :name,
      :provider,
      :model,
      :url_template,
      :api_key,
      :timeout,
      :recv_timeout
    ])
  end
end
