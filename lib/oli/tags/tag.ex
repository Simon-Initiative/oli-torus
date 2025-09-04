defmodule Oli.Tags.Tag do
  @moduledoc """
  Schema for tags that can be associated with projects, sections, and products.

  Tags provide a way to categorize and organize projects, sections, and products
  for easier browsing and management in the admin interface.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Tags.{ProjectTag, SectionTag}

  schema "tags" do
    field :name, :string
    timestamps(type: :utc_datetime)

    # Associations
    many_to_many :projects, Oli.Authoring.Course.Project, join_through: ProjectTag
    many_to_many :sections, Oli.Delivery.Sections.Section, join_through: SectionTag
  end

  @doc """
  Creates a changeset for a tag.
  """
  @spec changeset(Tag | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(tag, attrs \\ %{}) do
    tag
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint(:name)
  end
end
