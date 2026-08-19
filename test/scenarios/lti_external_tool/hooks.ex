defmodule Oli.Scenarios.LtiExternalTool.Hooks do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance
  alias Oli.Activities
  alias Oli.Activities.ActivityRegistrationProject
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment
  alias Oli.Lti.PlatformInstances
  alias Oli.Repo
  alias Oli.Scenarios.DirectiveTypes.ExecutionState

  @default_tool_name "LTI Example Tool"
  @default_tool_description "Dummy LTI example tool for Playwright launch validation"
  @default_tool_base_url "https://lti-example-tool.oli.cmu.edu"
  @default_client_id "EXAMPLE_CLIENT_ID"
  @default_project_name "lti_external_tool_project"

  def ensure_dummy_lti_tool(%ExecutionState{} = state) do
    attrs = dummy_tool_attrs(state.params)

    {:ok, platform_instance} = upsert_platform_instance(attrs)

    {:ok, activity_registration} =
      Activities.register_lti_external_tool_activity(
        attrs.name,
        attrs.name,
        attrs.description
      )

    {:ok, deployment} = upsert_deployment(platform_instance, activity_registration)
    :ok = enable_tool_for_project(state, activity_registration)

    %{state | params: put_tool_outputs(state.params, deployment)}
  end

  defp dummy_tool_attrs(params) do
    base_url =
      params
      |> param("DUMMY_LTI_TOOL_BASE_URL", "dummy_lti_tool_base_url")
      |> fallback_env("DUMMY_LTI_TOOL_BASE_URL")
      |> fallback_value(@default_tool_base_url)
      |> String.trim_trailing("/")

    %{
      status: :active,
      name: param(params, "DUMMY_LTI_TOOL_NAME", "dummy_lti_tool_name") || @default_tool_name,
      description:
        param(params, "DUMMY_LTI_TOOL_DESCRIPTION", "dummy_lti_tool_description") ||
          @default_tool_description,
      client_id:
        params
        |> param("DUMMY_LTI_TOOL_CLIENT_ID", "dummy_lti_tool_client_id")
        |> fallback_env("DUMMY_LTI_TOOL_CLIENT_ID")
        |> fallback_value(@default_client_id),
      target_link_uri: "#{base_url}/launch",
      login_url: "#{base_url}/login",
      keyset_url: "#{base_url}/.well-known/jwks.json",
      redirect_uris: "#{base_url}/launch",
      custom_params: ""
    }
  end

  defp upsert_platform_instance(%{client_id: client_id} = attrs) do
    case active_platform_instance(client_id) do
      nil -> PlatformExternalTools.create_platform_instance(attrs)
      platform_instance -> PlatformInstances.update_platform_instance(platform_instance, attrs)
    end
  end

  defp active_platform_instance(client_id) do
    PlatformInstance
    |> where([p], p.client_id == ^client_id and p.status == :active)
    |> Repo.one()
  end

  defp upsert_deployment(platform_instance, activity_registration) do
    case deployment_for(platform_instance, activity_registration) do
      nil ->
        PlatformExternalTools.create_lti_external_tool_activity_deployment(%{
          platform_instance_id: platform_instance.id,
          activity_registration_id: activity_registration.id,
          status: :enabled,
          deep_linking_enabled: false
        })

      deployment ->
        PlatformExternalTools.update_lti_external_tool_activity_deployment(deployment, %{
          platform_instance_id: platform_instance.id,
          activity_registration_id: activity_registration.id,
          status: :enabled,
          deep_linking_enabled: false
        })
    end
  end

  defp deployment_for(platform_instance, activity_registration) do
    LtiExternalToolActivityDeployment
    |> where(
      [d],
      d.platform_instance_id == ^platform_instance.id or
        d.activity_registration_id == ^activity_registration.id
    )
    |> Repo.one()
  end

  defp enable_tool_for_project(%ExecutionState{} = state, activity_registration) do
    project_name =
      state.params
      |> param("project_name", "PROJECT_NAME")
      |> fallback_value(@default_project_name)

    case Map.get(state.projects, project_name) do
      nil ->
        :ok

      built_project ->
        attrs = %{
          project_id: built_project.project.id,
          activity_registration_id: activity_registration.id,
          status: :enabled
        }

        case Repo.get_by(ActivityRegistrationProject,
               project_id: attrs.project_id,
               activity_registration_id: attrs.activity_registration_id
             ) do
          nil ->
            %ActivityRegistrationProject{}
            |> ActivityRegistrationProject.changeset(attrs)
            |> Repo.insert!()

          registration_project ->
            registration_project
            |> ActivityRegistrationProject.changeset(attrs)
            |> Repo.update!()
        end

        :ok
    end
  end

  defp param(params, primary_key, alternate_key) do
    Map.get(params, primary_key) || Map.get(params, alternate_key)
  end

  defp fallback_env(nil, env_name), do: System.get_env(env_name)
  defp fallback_env(value, _env_name), do: value

  defp fallback_value(nil, value), do: value
  defp fallback_value("", value), do: value
  defp fallback_value(value, _value), do: value

  defp put_tool_outputs(params, deployment) do
    params
    |> Map.put("dummy_lti_tool_deployment_id", deployment.deployment_id)
    |> Map.put("dummy_lti_platform_issuer", Oli.Utils.get_base_url())
  end
end
