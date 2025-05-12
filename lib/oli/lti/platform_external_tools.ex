defmodule Oli.Lti.PlatformExternalTools do
  @moduledoc """
  The PlatformExternalTools context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  import Oli.Utils, only: [trap_nil: 1]

  alias Oli.Repo
  alias Oli.Activities
  alias Oli.Activities.ActivityRegistration
  alias Oli.Lti.PlatformExternalTools.{BrowseOptions, LtiExternalToolActivityDeployment}
  alias Oli.Repo.{Paging, Sorting}
  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance

  @doc """
  Lists all lti external tool deployments.
  """
  def list_lti_external_tool_activity_deployments do
    Repo.all(LtiExternalToolActivityDeployment)
  end

  @doc """
  Gets a single lti external tool deployment by ID.
  Raises `Ecto.NoResultsError` if the LtiExternalToolActivityDeployment does not exist.
  """
  def get_lti_external_tool_activity_deployment!(id) do
    Repo.get!(LtiExternalToolActivityDeployment, id)
  end

  @doc """
  Gets a single lti external tool deployment by attributes.
  Raises `Ecto.NoResultsError` if the LtiExternalToolActivityDeployment does not exist.
  """
  def get_lti_external_tool_activity_deployment_by(attrs) do
    LtiExternalToolActivityDeployment
    |> where(^attrs)
    |> preload(:platform_instance)
    |> Repo.one()
  end

  @doc """
  Creates a lti external tool deployment.
  """
  def create_lti_external_tool_activity_deployment(attrs \\ %{}) do
    %LtiExternalToolActivityDeployment{}
    |> LtiExternalToolActivityDeployment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a lti external tool platform instance, deployment and registers the activity.
  """
  def register_lti_external_tool_activity(platform_instance_params) do
    Repo.transaction(fn ->
      with {:ok, platform_instance} <-
             create_platform_instance(platform_instance_params),
           {:ok, activity_registration} <-
             Activities.register_lti_external_tool_activity(
               platform_instance_params["name"],
               platform_instance_params["name"],
               platform_instance_params["description"]
             ),
           {:ok, deployment} <-
             create_lti_external_tool_activity_deployment(%{
               platform_instance_id: platform_instance.id,
               activity_registration_id: activity_registration.id
             }) do
        {platform_instance, activity_registration, deployment}
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Updates a LTI external tool activity.

  ## Examples

      iex> update_lti_external_tool_activity(1, %{field: new_value})
      {:ok, %{platform_instance: %PlatformInstance{}, activity_registration: %ActivityRegistration{}}}

      iex> update_lti_external_tool_activity(456, %{field: bad_value})
      {:error, :updated_platform_instance, %Ecto.Changeset{}, %{}}

  """
  @spec update_lti_external_tool_activity(
          integer(),
          map()
        ) :: {:ok, map()} | {:error, atom(), Ecto.Changeset.t(), map()}
  def update_lti_external_tool_activity(platform_instance_id, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:platform_instance, fn _, _ ->
      platform_instance_id
      |> get_platform_instance()
      |> trap_nil()
    end)
    |> Ecto.Multi.update(:updated_platform_instance, fn %{platform_instance: platform_instance} ->
      change_platform_instance(platform_instance, attrs)
    end)
    |> Ecto.Multi.run(:activity_registration, fn repo, _ ->
      from(
        a in ActivityRegistration,
        join: etad in LtiExternalToolActivityDeployment,
        on: etad.activity_registration_id == a.id,
        where: etad.platform_instance_id == ^platform_instance_id
      )
      |> repo.one()
      |> trap_nil()
    end)
    |> Ecto.Multi.update(:updated_activity_registration, fn %{
                                                              activity_registration:
                                                                activity_registration
                                                            } ->
      activity_attrs = %{
        title: attrs["name"],
        petite_label: attrs["name"],
        description: attrs["description"]
      }

      ActivityRegistration.changeset(activity_registration, activity_attrs)
    end)
    |> Repo.transaction()
  end

  @doc """
  Deletes a lti external tool deployment.
  """
  def delete_lti_external_tool_activity_deployment(
        %LtiExternalToolActivityDeployment{} = lti_external_tool_activity_deployment
      ) do
    Repo.delete(lti_external_tool_activity_deployment)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking lti external tool deployment changes.
  """
  def change_lti_external_tool_activity_deployment(
        %LtiExternalToolActivityDeployment{} = lti_external_tool_activity_deployment,
        attrs \\ %{}
      ) do
    LtiExternalToolActivityDeployment.changeset(lti_external_tool_activity_deployment, attrs)
  end

  @doc """
  Browse platform external tools with support for pagination, sorting, text search and status filter.

  ## Examples

      iex> browse_platform_external_tools(%Paging{}, %Sorting{}, %BrowseOptions{})
      {[%PlatformInstance{}, ...], total_count}

  """
  def browse_platform_external_tools(
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

    usage_counts_query =
      from ar in ActivityRegistration,
        join: letad in LtiExternalToolActivityDeployment,
        on: letad.activity_registration_id == ar.id,
        join: pi in PlatformInstance,
        on: pi.id == letad.platform_instance_id,
        group_by: pi.id,
        select: %{platform_instance_id: pi.id, usage_count: count(ar.id, :distinct)}

    query =
      from p in PlatformInstance,
        join: lad in LtiExternalToolActivityDeployment,
        on: lad.platform_instance_id == p.id,
        left_join: uc in subquery(usage_counts_query),
        on: uc.platform_instance_id == p.id,
        where: ^filter_by_text,
        where: ^filter_by_status,
        limit: ^limit,
        offset: ^offset,
        select: %{
          id: p.id,
          name: p.name,
          description: p.description,
          inserted_at: p.inserted_at,
          usage_count: coalesce(uc.usage_count, 0),
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
  Returns an `%Ecto.Changeset{}` for tracking platform_instance changes.

  ## Examples

      iex> change_platform_instance(platform_instance)
      %Ecto.Changeset{data: %PlatformInstance{}}

  """
  def change_platform_instance(%PlatformInstance{} = platform_instance, attrs \\ %{}) do
    PlatformInstance.changeset(platform_instance, attrs)
    |> unique_constraint(:client_id)
  end

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
    |> change_platform_instance(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single platform_instance by ID.
  Returns `nil` if the PlatformInstance does not exist.

  ## Examples

      iex> get_platform_instance(id)
      %PlatformInstance{}

      iex> get_platform_instance(456)
      nil
  """
  @spec get_platform_instance(integer()) :: %PlatformInstance{}
  def get_platform_instance(platform_instance_id) do
    Repo.get(PlatformInstance, platform_instance_id)
  end
end
