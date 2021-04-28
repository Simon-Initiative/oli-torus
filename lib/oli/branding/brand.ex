defmodule Oli.Branding.Brand do
  use Ecto.Schema
  import Ecto.Changeset

  import Oli.Utils
  alias Oli.Utils.Slug

  schema "brands" do
    field :name, :string
    field :slug, :string
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
    slug = value_or(attrs["slug"], Slug.generate("brands", attrs["name"]))
    attrs = attrs
      |> Map.put("slug", slug)
      |> cast_upload_to_url(slug, [:logo, :logo_dark, :favicons, :favicons_dark])

    brand
    |> cast(attrs, [:name, :slug, :logo, :logo_dark, :favicons, :favicons_dark, :institution_id])
    |> validate_required([:name, :logo, :favicons])
  end

  def cast_upload_to_url(attrs, slug, terms) when is_list(terms) do
    Enum.reduce(terms, attrs, fn term, acc ->
      cast_upload_to_url(acc, slug, term)
    end)
  end

  def cast_upload_to_url(attrs, slug, term) do
    media_url = Application.fetch_env!(:oli, :media_url)
    term = to_string(term)

    case attrs[term] do
      %Plug.Upload{filename: filename} ->
        Map.put(attrs, term, "https://#{media_url}/brands/#{slug}/#{filename}")

      uploads when is_list(uploads) ->
        Map.put(attrs, term, "https://#{media_url}/brands/#{slug}/#{to_charlist(term)}")

      _ ->
        attrs
    end
  end
end
