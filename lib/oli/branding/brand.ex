defmodule Oli.Branding.Brand do
  use Ecto.Schema
  import Ecto.Changeset

  schema "brands" do
    field :name, :string
    field :favicons, :string
    field :favicons_dark, :string
    field :logo, :string
    field :logo_dark, :string

    belongs_to :institution, Oli.Institutions.Institution
    has_many :registrations, Oli.Lti_1p3.Tool.Registration

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [:name, :logo, :logo_dark, :favicons, :favicons_dark, :institution_id])
    |> validate_required([:name])
  end
end
