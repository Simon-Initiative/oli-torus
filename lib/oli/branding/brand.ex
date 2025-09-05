defmodule Oli.Branding.Brand do
  use Ecto.Schema
  import Ecto.Changeset

  import Oli.Utils
  alias Oli.Utils.Slug

  schema "brands" do
    field(:name, :string)
    field(:slug, :string)
    field(:favicons, :string)
    field(:logo, :string)
    field(:logo_dark, :string)

    # a brand can be applied to a specific section by setting the brand_id
    # within that section
    has_many(:sections, Oli.Delivery.Sections.Section)

    # a brand may be associated with a particular institution in which case the brand
    # can (and only) be selected by instuctors that belong to that particular institution
    belongs_to(:institution, Oli.Institutions.Institution)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [:name, :slug, :logo, :logo_dark, :favicons, :institution_id])
    |> validate_required([:name, :logo, :favicons])
    |> Slug.update_never("brands")
  end

  def cast_file_params(params) do
    slug = value_or(params["slug"], Slug.generate("brands", params["name"]))

    params
    |> Map.put("slug", slug)
    |> cast_upload_to_url(slug, [:logo, :logo_dark, :favicons])
  end

  defp cast_upload_to_url(attrs, slug, terms) when is_list(terms) do
    Enum.reduce(terms, attrs, fn term, acc ->
      cast_upload_to_url(acc, slug, term)
    end)
  end

  defp cast_upload_to_url(attrs, slug, term) do
    media_url = Application.fetch_env!(:oli, :media_url)
    term = to_string(term)

    case attrs[term] do
      %Plug.Upload{filename: filename} ->
        Map.put(attrs, term, "#{media_url}/brands/#{slug}/#{filename}")

      uploads when is_list(uploads) ->
        Map.put(attrs, term, "#{media_url}/brands/#{slug}/#{to_charlist(term)}")

      _ ->
        attrs
    end
  end
end
