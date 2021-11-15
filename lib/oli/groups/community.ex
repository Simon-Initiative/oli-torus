defmodule Oli.Groups.Community do
  use Ecto.Schema
  import Ecto.Changeset

  schema "communities" do
    field :name, :string
    field :description, :string
    field :key_contact, :string
    field :global_access, :boolean, default: true
    field :status, Ecto.Enum, values: [:active, :deleted], default: :active

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(community, attrs \\ %{}) do
    community
    |> cast(attrs, [:name, :description, :key_contact, :global_access, :status])
    |> validate_required([:name, :global_access, :status])
    |> unique_constraint(:name)
  end
end
