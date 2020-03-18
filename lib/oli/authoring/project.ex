defmodule Oli.Authoring.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    timestamps()
    field :title, :string
    field :slug, :string
    field :description, :string
    field :version, :string

    belongs_to :parent_project, Oli.Authoring.Project, foreign_key: :project_id
    belongs_to :project_family, Oli.Authoring.ProjectFamily
    many_to_many :authors, Oli.Accounts.Author, join_through: "authors_projects"
  end

  @doc false
  def changeset(author, attrs \\ %{}) do
    author
    |> cast(attrs, [
      :title,
      :slug,
      :description,
      :issues,
      :version
    ])
    |> validate_required([:title, :slug, :version, :package_family, :authors, :creator])
    |> unique_constraint(:slug)
  end
end
