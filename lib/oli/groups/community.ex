defmodule Oli.Groups.Community do
  use Ecto.Schema
  import Ecto.Changeset

  schema "communities" do
    field :name, :string
    field :description, :string
    field :key_contact, :string
    field :global_access, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(community, attrs \\ %{}) do
    community
    |> cast(attrs, [:name, :description, :key_contact, :global_access])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
