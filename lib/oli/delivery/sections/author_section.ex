defmodule Oli.Delivery.Sections.AuthorSection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "authors_sections" do
    timestamps()
    belongs_to :author, Oli.Accounts.Author
    belongs_to :section, Oli.Delivery.Sections.Section
    belongs_to :section_role, Oli.Delivery.Sections.SectionRole
  end

  @doc false
  def changeset(user_section, attrs \\ %{}) do
    user_section
    |> cast(attrs, [:author_id, :section_id, :section_role_id])
    |> validate_required([:author_id, :section_id, :section_role_id])
  end
end
