defmodule Oli.Inventories.Publisher do
  use Ecto.Schema
  import Ecto.Changeset

  schema "publishers" do
    field :name, :string
    field :email, :string
    field :address, :string
    field :main_contact, :string
    field :website_url, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(publisher, attrs \\ %{}) do
    publisher
    |> cast(attrs, [:name, :email, :address, :main_contact, :website_url])
    |> validate_required([:name, :email])
    |> unique_constraint(:name)
  end
end
