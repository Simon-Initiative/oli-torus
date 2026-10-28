defmodule Oli.Scenarios.DotChatbot.BootstrapTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.GenAI.Dev.LocalCodex
  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @scenario_path Path.expand(
                   "../../../assets/automation/tests/torus/dot_chatbot/dot-chatbot.scenario.yaml",
                   __DIR__
                 )

  test "bootstrap creates a Dot-enabled section and enrolled student" do
    suffix = System.unique_integer([:positive])
    service_name = "dot-smoke-service-#{suffix}"

    assert {:ok, _result} =
             LocalCodex.setup(%{
               model_name: "dot-smoke-model-#{suffix}",
               service_name: service_name
             })

    params = %{
      "PROJECT_NAME" => "dot_smoke_project_#{suffix}",
      "PROJECT_TITLE" => "Dot Smoke Project #{suffix}",
      "PAGE_TITLE" => "Dot Smoke Page",
      "SECTION_NAME" => "dot_smoke_section_#{suffix}",
      "SECTION_TITLE" => "Dot Smoke Section #{suffix}",
      "STUDENT_NAME" => "dot_smoke_student_#{suffix}",
      "STUDENT_EMAIL" => "dot-smoke-student-#{suffix}@example.com",
      "STUDENT_GIVEN_NAME" => "Dot",
      "STUDENT_FAMILY_NAME" => "Student",
      "STUDENT_PASSWORD" => "local-dot-smoke-password",
      "ASSISTANT_SERVICE_CONFIG" => service_name
    }

    yaml = interpolate(File.read!(@scenario_path), params)

    assert :ok = Scenarios.validate_yaml(yaml)

    result = Scenarios.execute_yaml(yaml, RuntimeOpts.build(params: params))

    assert result.errors == []
    assert [verification] = result.verifications
    assert verification.passed

    section = Scenarios.get_section(result, params["SECTION_NAME"])
    student = Scenarios.get_user(result, params["STUDENT_NAME"])

    assert section.assistant_enabled
    assert Sections.get_enrollment(section.slug, student.id)
  end

  defp interpolate(yaml, params) do
    Enum.reduce(params, yaml, fn {name, value}, interpolated ->
      String.replace(interpolated, "${#{name}}", to_string(value))
    end)
  end
end
