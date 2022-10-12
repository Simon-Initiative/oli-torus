defmodule Oli.Delivery.Sections.SectionCustomizations do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :unit_label, :string
    field :module_label, :string
    field :section_label, :string
  end

  def changeset(preferences, attrs \\ %{}) do
    preferences
    |> cast(attrs, [:unit_label, :module_label, :section_label])
  end
end
