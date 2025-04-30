defmodule Oli.Lti.PlatformInstances do
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance
  alias Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment
  alias Oli.Lti.PlatformInstances.BrowseOptions
  alias Oli.Repo.{Paging, Sorting}

  @doc """
  Browse platform instances with support for pagination, sorting, text search and status filter.

  ## Examples

      iex> browse_platform_instances(%Paging{}, %Sorting{}, %BrowseOptions{})
      {[%PlatformInstance{}, ...], total_count}

  """
  def browse_platform_instances(
        %Paging{limit: limit, offset: offset},
        %Sorting{field: field, direction: direction},
        %BrowseOptions{} = options
      ) do
    filter_by_text =
      if options.text_search == "" or is_nil(options.text_search) do
        true
      else
        text_search = String.trim(options.text_search)

        dynamic(
          [p],
          ilike(p.name, ^"%#{text_search}%") or
            ilike(p.description, ^"%#{text_search}%")
        )
      end

    filter_by_status =
      if options.include_disabled do
        true
      else
        dynamic([p, lad], lad.status == :enabled)
      end

    # TODO: calculate usage_count (we need https://eliterate.atlassian.net/browse/MER-4469)
    # for now we set a random number between 0 and 100
    query =
      from p in PlatformInstance,
        join: lad in LtiExternalToolActivityDeployment,
        on: lad.platform_instance_id == p.id,
        where: ^filter_by_text,
        where: ^filter_by_status,
        limit: ^limit,
        offset: ^offset,
        select: %{
          id: p.id,
          name: p.name,
          description: p.description,
          inserted_at: p.inserted_at,
          usage_count: fragment("floor(random() * 101)::integer AS usage_count"),
          status: lad.status,
          total_count: fragment("count(*) OVER()")
        }

    query =
      case field do
        field when field in [:name, :description, :inserted_at] ->
          order_by(query, [p], {^direction, field(p, ^field)})

        :usage_count ->
          order_by(query, [p, lad], {^direction, fragment("usage_count")})

        :status ->
          order_by(query, [_p, lad], {^direction, lad.status})
      end

    Repo.all(query)
  end

  @doc """
  Returns the list of lti_1p3_platform_instances.

  ## Examples

      iex> list_lti_1p3_platform_instance_instances()
      [%PlatformInstance{}, ...]

  """
  def list_lti_1p3_platform_instances do
    Repo.all(PlatformInstance)
  end

  @doc """
  Gets a single platform_instance.

  Raises `Ecto.NoResultsError` if the PlatformInstance does not exist.

  ## Examples

      iex> get_platform_instance!(123)
      %PlatformInstance{}

      iex> get_platform_instance!(456)
      ** (Ecto.NoResultsError)

  """
  def get_platform_instance!(id), do: Repo.get!(PlatformInstance, id)

  @doc """
  Gets a single platform_instance by client id
  ## Examples

      iex> get_platform_instance_by_client_id("123")
      %PlatformInstance{}

      iex> get_platform_instance_by_client_id("456")
      nil

  """
  def get_platform_instance_by_client_id(client_id),
    do: Repo.get_by(PlatformInstance, client_id: client_id)

  @doc """
  Creates a platform_instance.

  ## Examples

      iex> create_platform_instance(%{field: value})
      {:ok, %PlatformInstance{}}

      iex> create_platform_instance(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_platform_instance(attrs \\ %{}) do
    %PlatformInstance{}
    |> PlatformInstance.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a platform_instance.

  ## Examples

      iex> update_platform_instance(platform_instance, %{field: new_value})
      {:ok, %PlatformInstance{}}

      iex> update_platform_instance(platform_instance, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_platform_instance(%PlatformInstance{} = platform_instance, attrs) do
    platform_instance
    |> PlatformInstance.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a platform_instance.

  ## Examples

      iex> delete_platform_instance(platform_instance)
      {:ok, %PlatformInstance{}}

      iex> delete_platform_instance(platform_instance)
      {:error, %Ecto.Changeset{}}

  """
  def delete_platform_instance(%PlatformInstance{} = platform_instance) do
    Repo.delete(platform_instance)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking platform_instance changes.

  ## Examples

      iex> change_platform_instance(platform_instance)
      %Ecto.Changeset{data: %PlatformInstance{}}

  """
  def change_platform_instance(%PlatformInstance{} = platform_instance, attrs \\ %{}) do
    PlatformInstance.changeset(platform_instance, attrs)
  end
end
