defmodule Oli.Authoring.Activities.Registration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_registrations" do
    field :authoring_script, :string
    field :delivery_script, :string
    field :description, :string
    field :element_name, :string
    field :icon, :string
    field :title, :string

    timestamps()
  end

  @doc false
  def changeset(registration, attrs) do
    registration
    |> cast(attrs, [:title, :icon, :description, :element_name, :delivery_script, :authoring_script])
    |> validate_required([:title, :icon, :description, :element_name, :delivery_script, :authoring_script])
  end
end
