defmodule Oli.Branding.CustomLabels do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :unit, :string
    field :module, :string
    field :section, :string
  end

  def changeset(labels, attrs \\ %{}) do
    labels
    |> cast(attrs, [:unit, :module, :section])
  end

  def default() do
    %__MODULE__{
      unit: "Unit",
      module: "Module",
      section: "Section"
    }
  end
end
