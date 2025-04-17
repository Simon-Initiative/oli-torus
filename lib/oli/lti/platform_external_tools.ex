defmodule Oli.Lti.PlatformExternalTools do
  @moduledoc """
  The PlatformExternalTools context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment
  alias Oli.Lti.PlatformInstances
  alias Oli.Activities

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
             PlatformInstances.create_platform_instance(platform_instance_params),
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
end
