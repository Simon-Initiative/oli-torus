defmodule Oli.Host.HostIdentifier do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "host_identifier" do
    field :id, :integer, default: 1
    field :hostname, :string

    timestamps(type: :utc_datetime)
  end

  @required_fields [:id, :hostname]

  def changeset(host_identifier, attrs \\ %{}) do
    host_identifier
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> check_constraint(:id, name: :one_row, message: "must be 1")
    |> unique_constraint(:id, name: :host_identifier_id_index)
  end
end
