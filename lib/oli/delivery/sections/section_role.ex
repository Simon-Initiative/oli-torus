defmodule Oli.Delivery.Sections.SectionRole do
  use Ecto.Schema
  import Ecto.Changeset

  schema "section_roles" do
    field :type, :string
    timestamps()
  end

  @doc false
  def changeset(section_role, attrs \\ %{}) do
    section_role
    |> cast(attrs, [:type])
    |> validate_required([:type])
  end

  @instructor %Oli.Delivery.Sections.SectionRole{
    id: 1,
    type: "instructor"
  }

  @student %Oli.Delivery.Sections.SectionRole{
    id: 2,
    type: "student"
  }

  def get_section_roles(), do: [@instructor, @student]

  def get_section_role_by_id(1), do: @instructor
  def get_section_role_by_id(2), do: @student

  def get_section_role_by_type("instructor"), do: @instructor
  def get_section_role_by_type("student"), do: @student


end
