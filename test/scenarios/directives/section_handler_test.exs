defmodule Oli.Scenarios.Directives.SectionHandlerTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts
  alias Oli.Delivery.Sections.Section
  alias Oli.GenAI.Dev.LocalCodex
  alias Oli.GenAI.FeatureConfig

  test "creates a section with the Dot assistant enabled" do
    yaml = """
    - project:
        name: "dot_project"
        title: "Dot Project"
        root:
          children:
            - page: "Welcome"

    - section:
        name: "dot_section"
        title: "Dot Section"
        from: "dot_project"
        assistant_enabled: true
    """

    result = Scenarios.execute_yaml(yaml, RuntimeOpts.build())

    assert result.errors == []
    assert Scenarios.get_section(result, "dot_section").assistant_enabled
  end

  test "reports an error when the assistant-enabled section source does not exist" do
    yaml = """
    - section:
        name: "missing_source_section"
        from: "missing_project"
        assistant_enabled: true
    """

    result = Scenarios.execute_yaml(yaml, RuntimeOpts.build())

    assert [{_directive, message}] = result.errors
    assert message =~ "Project or product 'missing_project' not found"
  end

  test "selects a named GenAI service for Dot on the created section" do
    assert {:ok, %{service_config: service_config}} =
             LocalCodex.setup(%{
               model_name: "scenario-dot-model",
               service_name: "scenario-dot-service"
             })

    yaml = """
    - project:
        name: "configured_dot_project"
        title: "Configured Dot Project"
        root:
          children:
            - page: "Welcome"

    - section:
        name: "configured_dot_section"
        from: "configured_dot_project"
        assistant_enabled: true
        assistant_service_config: "scenario-dot-service"
    """

    result = Scenarios.execute_yaml(yaml, RuntimeOpts.build())

    assert result.errors == []
    section = Scenarios.get_section(result, "configured_dot_section")

    assert %FeatureConfig{service_config_id: service_config_id} =
             Repo.get_by(FeatureConfig,
               feature: :student_dialogue,
               section_id: section.id
             )

    assert service_config_id == service_config.id
  end

  test "reports an error when the named Dot service does not exist" do
    yaml = """
    - project:
        name: "missing_service_project"
        title: "Missing Service Project"
        root:
          children:
            - page: "Welcome"

    - section:
        name: "configured_dot_section"
        from: "missing_service_project"
        assistant_enabled: true
        assistant_service_config: "missing-dot-service"
    """

    result = Scenarios.execute_yaml(yaml, RuntimeOpts.build())

    assert [{_directive, message}] = result.errors
    assert message =~ "GenAI service config 'missing-dot-service' not found"
    refute Repo.get_by(Section, title: "configured_dot_section")
  end

  test "requires Dot to be enabled when selecting an assistant service" do
    yaml = """
    - section:
        name: "disabled_dot_section"
        assistant_service_config: "some-dot-service"
    """

    result = Scenarios.execute_yaml(yaml, RuntimeOpts.build())

    assert [{_directive, message}] = result.errors
    assert message =~ "requires assistant_enabled: true"
  end
end
