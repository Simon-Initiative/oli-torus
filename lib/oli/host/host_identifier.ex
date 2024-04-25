defmodule Oli.Host.HostIdentifier do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "host_identifier" do
    field :id, :integer, default: 1
    field :host, :string

    timestamps(type: :utc_datetime)
  end

  @required_fields [:id, :host]

  def changeset(host_identifier, attrs \\ %{}) do
    host_identifier
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> check_constraint(:id, name: :one_row)
    |> unique_constraint(:id, name: :host_identifier_id_index)
  end
end
