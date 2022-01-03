defmodule Oli.Institutions.Institution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "institutions" do
    field :name, :string
    field :country_code, :string
    field :institution_email, :string
    field :institution_url, :string
    field :timezone, :string

    # an institution can specify a default brand
    belongs_to :default_brand, Oli.Branding.Brand

    # LTI 1.3 Deployments
    has_many :sections, Oli.Delivery.Sections.Section

    # an institution may have multiple brands associated with it that instructors
    # can choose from when delivering thier section
    has_many :brands, Oli.Branding.Brand

    has_many :deployments, Oli.Lti_1p3.Tool.Deployment

    many_to_many :communities, Oli.Groups.Community, join_through: Oli.Groups.CommunityInstitution

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
      :timezone,
      :default_brand_id
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
