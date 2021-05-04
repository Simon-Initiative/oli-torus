defmodule Oli.Institutions.Institution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "institutions" do
    field :country_code, :string
    field :institution_email, :string
    field :institution_url, :string
    field :name, :string
    field :timezone, :string

    # LTI 1.3 Deployments
    has_many :registrations, Oli.Lti_1p3.Tool.Registration
    has_many :sections, Oli.Delivery.Sections.Section
    has_many :brands, Oli.Branding.Brand

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(institution, attrs \\ %{}) do
    institution
    |> cast(attrs, [
      :name,
      :country_code,
      :institution_email,
      :institution_url,
      :timezone
    ])
    |> validate_required([
      :name,
      :country_code,
      :institution_email,
      :institution_url,
      :timezone
    ])
  end
end
