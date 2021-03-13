defmodule Oli.Activities.ActivityRegistration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_registrations" do
    field :slug, :string
    field :authoring_script, :string
    field :delivery_script, :string
    field :description, :string
    field :authoring_element, :string
    field :delivery_element, :string
    field :icon, :string
    field :title, :string
    field :allow_client_evaluation, :boolean, default: false
    field :globally_available, :boolean, default: false
    many_to_many :projects, Oli.Authoring.Course.Project, join_through: Oli.Activities.ActivityRegistrationProject

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(registration, attrs) do
    registration
    |> cast(attrs, [:slug, :title, :icon, :description, :delivery_element, :authoring_element, :delivery_script,
      :authoring_script, :allow_client_evaluation, :globally_available])
    |> validate_required([:slug, :title, :icon, :description, :delivery_element, :authoring_element, :delivery_script, :authoring_script])
    |> unique_constraint(:slug)
    |> unique_constraint(:authoring_element)
    |> unique_constraint(:delivery_element)
    |> unique_constraint(:delivery_script)
    |> unique_constraint(:authoring_script)
  end
end
