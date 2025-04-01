defmodule Oli.Lti.PlatformExternalTools do
  @moduledoc """
  The PlatformExternalTools context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Lti.PlatformExternalTools.LtiExternalToolDeployment

  @doc """
  Lists all lti external tool deployments.
  """
  def list_lti_external_tool_deployments do
    Repo.all(LtiExternalToolDeployment)
  end

  @doc """
  Gets a single lti external tool deployment by ID.
  Raises `Ecto.NoResultsError` if the LtiExternalToolDeployment does not exist.
  """
  def get_lti_external_tool_deployment!(id) do
    Repo.get!(LtiExternalToolDeployment, id)
  end

  @doc """
  Gets a single lti external tool deployment by attributes.
  Raises `Ecto.NoResultsError` if the LtiExternalToolDeployment does not exist.
  """
  def get_lti_external_tool_deployment_by(attrs) do
    LtiExternalToolDeployment
    |> where(^attrs)
    |> Repo.one()
  end

  @doc """
  Creates a lti external tool deployment.
  """
  def create_lti_external_tool_deployment(attrs \\ %{}) do
    %LtiExternalToolDeployment{}
    |> LtiExternalToolDeployment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a lti external tool deployment.
  """
  def update_lti_external_tool_deployment(
        %LtiExternalToolDeployment{} = lti_external_tool_deployment,
        attrs
      ) do
    lti_external_tool_deployment
    |> LtiExternalToolDeployment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a lti external tool deployment.
  """
  def delete_lti_external_tool_deployment(
        %LtiExternalToolDeployment{} = lti_external_tool_deployment
      ) do
    Repo.delete(lti_external_tool_deployment)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking lti external tool deployment changes.
  """
  def change_lti_external_tool_deployment(
        %LtiExternalToolDeployment{} = lti_external_tool_deployment,
        attrs \\ %{}
      ) do
    LtiExternalToolDeployment.changeset(lti_external_tool_deployment, attrs)
  end
end
