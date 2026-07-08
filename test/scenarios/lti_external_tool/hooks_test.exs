defmodule Oli.Scenarios.LtiExternalTool.HooksTest do
  use Oli.DataCase

  alias Oli.Activities
  alias Oli.Activities.ActivityRegistrationProject
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Repo
  alias Oli.Scenarios.DirectiveParser
  alias Oli.Scenarios.Engine

  @run_id "-hooks-test"
  @base_url "http://localhost:8080"

  test "ensure_dummy_lti_tool registers and enables the dummy LTI tool idempotently" do
    yaml = """
    - project:
        name: "lti_external_tool_project"
        title: "LTI External Tool Course #{@run_id}"
        root:
          children:
            - page: "External Tool Launch"

    - hook:
        function: "Oli.Scenarios.LtiExternalTool.Hooks.ensure_dummy_lti_tool/1"

    - hook:
        function: "Oli.Scenarios.LtiExternalTool.Hooks.ensure_dummy_lti_tool/1"
    """

    directives = DirectiveParser.parse_yaml!(yaml)

    result =
      Engine.execute(directives,
        params: %{
          "DUMMY_LTI_TOOL_BASE_URL" => @base_url,
          "DUMMY_LTI_TOOL_CLIENT_ID" => "EXAMPLE_CLIENT_ID"
        }
      )

    assert result.errors == []

    activity_registration = Activities.get_registration_by_slug("lti_example_tool")
    assert activity_registration

    deployment =
      PlatformExternalTools.get_lti_external_tool_activity_deployment_by(
        activity_registration_id: activity_registration.id
      )

    assert deployment.status == :enabled
    assert deployment.deep_linking_enabled == false
    assert deployment.platform_instance.client_id == "EXAMPLE_CLIENT_ID"
    assert deployment.platform_instance.target_link_uri == "#{@base_url}/launch"
    assert deployment.platform_instance.login_url == "#{@base_url}/login"
    assert deployment.platform_instance.keyset_url == "#{@base_url}/.well-known/jwks.json"
    assert result.state.params["dummy_lti_tool_deployment_id"] == deployment.deployment_id
    assert result.state.params["dummy_lti_platform_issuer"] == Oli.Utils.get_base_url()

    built_project = result.state.projects["lti_external_tool_project"]

    registration_project =
      Repo.get_by!(ActivityRegistrationProject,
        project_id: built_project.project.id,
        activity_registration_id: activity_registration.id
      )

    assert registration_project.status == :enabled
  end
end
