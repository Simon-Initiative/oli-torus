defmodule Oli.Lti.PlatformExternalTools do
  @moduledoc """
  The PlatformExternalTools context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Oli.Repo

  alias Oli.Activities
  alias Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment
  alias Oli.Lti.PlatformExternalTools.BrowseOptions
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
  Updates a lti external tool deployment.
  """
  def update_lti_external_tool_activity_deployment(
        %LtiExternalToolActivityDeployment{} = lti_external_tool_activity_deployment,
        attrs
      ) do
    lti_external_tool_activity_deployment
    |> LtiExternalToolActivityDeployment.changeset(attrs)
    |> Repo.update()
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

    # TODO: calculate usage_count (we need https://eliterate.atlassian.net/browse/MER-4469)
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
          usage_count: fragment("NULL AS usage_count"),
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
end
