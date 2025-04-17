defmodule Oli.Branding do
  @moduledoc """
  The Branding context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  require Logger

  alias Oli.Branding.Brand
  alias Oli.Delivery.Sections.Section
  alias Oli.Lti.Tool.Deployment
  alias Oli.Institutions.Institution
  alias Oli.Utils

  @doc """
  Returns the list of brands.

  ## Examples

      iex> list_brands()
      [%Brand{}, ...]

  """
  def list_brands do
    Repo.all(Brand)
  end

  @doc """
  Returns the list of brands with stats.

  ## Examples

      iex> list_brands()
      [{%Brand{}, institutions_count, sections_count}, ...]

  """
  def list_brands_with_stats do
    from(b in Brand,
      left_join: i in Institution,
      on: i.default_brand_id == b.id,
      left_join: s in assoc(b, :sections),
      group_by: b.id,
      select: {b, count(i.id), count(s.id)}
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of available brands for an institution.

  ## Examples

      iex> list_available_brands(institution_id)
      [%Brand{}, ...]

  """
  def list_available_brands(institution_id) do
    from(b in Brand,
      where: b.institution_id == ^institution_id or is_nil(b.institution_id)
    )
    |> Repo.all()
  end

  def list_available_brands() do
    from(b in Brand,
      where: is_nil(b.institution_id)
    )
    |> Repo.all()
  end

  @doc """
  Gets a single brand.

  Raises `Ecto.NoResultsError` if the Brand does not exist.

  ## Examples

      iex> get_brand!(123)
      %Brand{}

      iex> get_brand!(456)
      ** (Ecto.NoResultsError)

  """
  def get_brand!(id), do: Repo.get!(Brand, id)

  @doc """
  Creates a brand.

  ## Examples

      iex> create_brand(%{field: value})
      {:ok, %Brand{}}

      iex> create_brand(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_brand(attrs \\ %{}) do
    %Brand{}
    |> Brand.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a brand.

  ## Examples

      iex> update_brand(brand, %{field: new_value})
      {:ok, %Brand{}}

      iex> update_brand(brand, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_brand(%Brand{} = brand, attrs) do
    brand
    |> Brand.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a brand.

  ## Examples

      iex> delete_brand(brand)
      {:ok, %Brand{}}

      iex> delete_brand(brand)
      {:error, %Ecto.Changeset{}}

  """
  def delete_brand(%Brand{} = brand) do
    Repo.delete(brand)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking brand changes.

  ## Examples

      iex> change_brand(brand)
      %Ecto.Changeset{data: %Brand{}}

  """
  def change_brand(%Brand{} = brand, attrs \\ %{}) do
    Brand.changeset(brand, attrs)
  end

  def get_section_brand(section \\ nil) do
    brand_with_defaults(section)
  end

  def brand_name(section \\ nil) do
    brand_with_defaults(section)
    |> Map.get(:name)
  end

  def brand_logo_url(section \\ nil) do
    brand_logo_path(section)
    |> Utils.ensure_absolute_url()
  end

  def brand_logo_url_dark(section \\ nil) do
    brand_logo_path_dark(section)
    |> Utils.ensure_absolute_url()
  end

  def brand_logo_path(section \\ nil) do
    brand_with_defaults(section)
    |> Map.get(:logo)
  end

  def brand_logo_path_dark(section \\ nil) do
    brand_with_defaults(section)
    |> Map.get(:logo_dark)
  end

  def favicons(name, section \\ nil) do
    favicons_dir =
      brand_with_defaults(section)
      |> Map.get(:favicons)

    "#{favicons_dir}/#{name}"
  end

  defp brand_with_defaults(section) do
    Map.merge(get_default_brand(), get_most_relevant_brand(section), fn _k, v1, v2 -> v2 || v1 end)
  end

  defp get_most_relevant_brand(section) do
    case section do
      nil ->
        # no section, use default compiled branding
        get_default_brand()

      %Section{brand: %Ecto.Association.NotLoaded{}} ->
        section
        |> ensure_preloaded([:brand])
        |> get_most_relevant_brand()

      %Section{brand: section_brand, open_and_free: true} ->
        section_institution_or_default(section_brand)

      %Section{lti_1p3_deployment: %Ecto.Association.NotLoaded{}} ->
        section
        |> ensure_preloaded(lti_1p3_deployment: [institution: [:default_brand]])
        |> get_most_relevant_brand()

      %Section{lti_1p3_deployment: %Deployment{institution: %Ecto.Association.NotLoaded{}}} ->
        section
        |> ensure_preloaded(lti_1p3_deployment: [institution: [:default_brand]])
        |> get_most_relevant_brand()

      %Section{
        brand: section_brand,
        lti_1p3_deployment: %Deployment{
          institution: %Institution{default_brand: institution_default_brand}
        }
      } ->
        section_institution_or_default(section_brand, institution_default_brand)

      _ ->
        get_default_brand()
    end
  end

  defp section_institution_or_default(section_brand, institution_default_brand \\ nil) do
    case section_brand do
      nil ->
        case institution_default_brand do
          nil ->
            # no brand defined for section or registration, use default compiled branding
            get_default_brand()

          brand ->
            brand
        end

      brand ->
        brand
    end
  end

  defp ensure_preloaded(section, associations) do
    Logger.warning(
      "The section association #{inspect(associations)} has not been preloaded for branding. " <>
        "The association will be loaded now but may result in performance issues."
    )

    if Mix.env() == :test do
      raise "Branding associations must be preloaded"
    end

    section
    |> Repo.preload(associations)
  end

  # creates a brand object from the compiled default branding config
  defp get_default_brand() do
    default_branding = Application.get_env(:oli, :branding)

    %Brand{
      name: Keyword.get(default_branding, :name),
      logo: Keyword.get(default_branding, :logo),
      logo_dark: Keyword.get(default_branding, :logo_dark),
      favicons: Keyword.get(default_branding, :favicons)
    }
  end
end
