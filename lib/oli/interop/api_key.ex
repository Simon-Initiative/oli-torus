defmodule Oli.Interop.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  A schema for modeling third-party developer API keys.

  We do not store the actual key in the database, instead we treat it like a
  password and only store a hash of the key.

  Keys can have different "scopes" available to them.  All scopes can be enabled
  and disabled via the "status" attribute.

  The "hint" is merely a description that allows a UX to display information about the
  key, like who it was created for and perhaps why it was created.
  """

  schema "api_keys" do
    field :status, Ecto.Enum, values: [:enabled, :disabled], default: :enabled
    field :hash, :binary
    field :hint, :binary
    field :payments_enabled, :boolean, default: true
    field :products_enabled, :boolean, default: true
    field :registration_enabled, :boolean, default: false
    field :registration_namespace, :binary
    field :automation_setup_enabled, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(feature, attrs \\ %{}) do
    feature
    |> cast(attrs, [
      :status,
      :hash,
      :hint,
      :payments_enabled,
      :products_enabled,
      :registration_enabled,
      :registration_namespace,
      :automation_setup_enabled
    ])
    |> validate_required([
      :status,
      :hash,
      :hint
    ])
  end
end
