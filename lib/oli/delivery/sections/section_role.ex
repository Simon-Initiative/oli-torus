defmodule Oli.Delivery.Sections.SectionRole do
  use Ecto.Schema
  import Ecto.Changeset

  schema "section_roles" do
    field :type, :string
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section_role, attrs \\ %{}) do
    section_role
    |> cast(attrs, [:type])
    |> validate_required([:type])
  end


end
