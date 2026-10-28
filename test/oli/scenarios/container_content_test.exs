defmodule Oli.Scenarios.ContainerContentTest do
  use Oli.DataCase

  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Scenarios
  alias OliWeb.Curriculum.Rollup

  test "scenario-created containers always have traversable page content" do
    yaml = """
    - project:
        name: "container_content_course"
        title: "Container Content Course"
        root:
          children:
            - container: "Initial Unit"
              children:
                - page: "Initial Page"
            - page: "Course Overview"

    - manipulate:
        to: "container_content_course"
        ops:
          - add_container:
              title: "Added Unit"
    """

    result = Scenarios.execute_yaml(yaml)

    assert result.errors == []

    built_project = result.state.projects["container_content_course"]

    children =
      ContainerEditor.list_all_container_children(
        built_project.root.revision,
        built_project.project
      )

    assert {:ok, %Rollup{}} = Rollup.new(children, built_project.project.slug)

    Enum.each(["Initial Unit", "Added Unit"], fn title ->
      assert %{"version" => "0.1.0", "model" => model} =
               built_project.rev_by_title[title].content

      assert is_list(model)
    end)
  end
end
