defmodule Oli.Accounts.AuthorSection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "authors_sections" do
    timestamps()
    belongs_to :author, Oli.Accounts.Author
    belongs_to :section, Oli.Delivery.Section
    belongs_to :section_role, Oli.Accounts.SectionRole
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:author_id, :section_id, :section_role_id])
    |> validate_required([:author_id, :section_id, :section_role_id])
  end
end
