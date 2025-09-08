defmodule Oli.Scenarios.CloneDirectiveTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Authoring.Clone

  describe "clone directive" do
    setup do
      # Create a test project with some resources
      project_map = Oli.Seeder.base_project_with_resource2()

      # Get the author from the project map
      author = project_map.author

      %{
        project: project_map.project,
        author: author,
        publication: project_map.publication,
        page1: project_map.page1,
        page2: project_map.page2
      }
    end

    test "successfully clones a project", %{project: source_project, author: author} do
      yaml = """
      - clone:
          from: source_project
          name: cloned_project
          title: "Cloned Test Project"
      """

      # Parse the directives
      directives = Oli.Scenarios.DirectiveParser.parse_yaml!(yaml)

      # Execute with the source project in state
      initial_state = %Oli.Scenarios.DirectiveTypes.ExecutionState{
        projects: %{
          "source_project" => %Oli.Scenarios.Types.BuiltProject{
            project: source_project,
            working_pub: Oli.Publishing.project_working_publication(source_project.slug),
            root: %{},
            id_by_title: %{},
            rev_by_title: %{},
            objectives_by_title: %{},
            tags_by_title: %{}
          }
        },
        sections: %{},
        products: %{},
        users: %{},
        institutions: %{},
        activities: %{},
        activity_virtual_ids: %{},
        page_attempts: %{},
        activity_evaluations: %{},
        current_author: author,
        current_institution: nil
      }

      result = Scenarios.execute(directives, author: author, state: initial_state)

      # Verify the clone was successful
      assert result.errors == []
      assert Map.has_key?(result.state.projects, "cloned_project")

      cloned = result.state.projects["cloned_project"]
      assert cloned.project.title == "Cloned Test Project"

      # Verify the project was actually cloned in the database
      clones = Clone.existing_clones(source_project.slug, author)
      assert length(clones) > 0
      assert Enum.any?(clones, fn clone -> clone.title == "Cloned Test Project" end)
    end

    test "uses default title when not specified", %{project: source_project, author: author} do
      yaml = """
      - clone:
          from: source_project
          name: cloned_project
      """

      directives = Oli.Scenarios.DirectiveParser.parse_yaml!(yaml)

      initial_state = %Oli.Scenarios.DirectiveTypes.ExecutionState{
        projects: %{
          "source_project" => %Oli.Scenarios.Types.BuiltProject{
            project: source_project,
            working_pub: Oli.Publishing.project_working_publication(source_project.slug),
            root: %{},
            id_by_title: %{},
            rev_by_title: %{},
            objectives_by_title: %{},
            tags_by_title: %{}
          }
        },
        sections: %{},
        products: %{},
        users: %{},
        institutions: %{},
        activities: %{},
        activity_virtual_ids: %{},
        page_attempts: %{},
        activity_evaluations: %{},
        current_author: author,
        current_institution: nil
      }

      result = Scenarios.execute(directives, author: author, state: initial_state)

      assert result.errors == []
      cloned = result.state.projects["cloned_project"]
      # Clone.clone_project adds " Copy" suffix by default
      assert cloned.project.title == "#{source_project.title} Copy"
    end

    test "fails when source project doesn't exist", %{author: author} do
      yaml = """
      - clone:
          from: non_existent_project
          name: cloned_project
      """

      directives = Oli.Scenarios.DirectiveParser.parse_yaml!(yaml)

      result = Scenarios.execute(directives, author: author)

      assert length(result.errors) == 1
      [{_directive, error_message}] = result.errors
      assert error_message =~ "Source project 'non_existent_project' not found"
    end

    test "clone directive can be used in complex scenarios", %{author: author} do
      yaml = """
      - project:
          name: original
          title: "Original Project"
          root:
            container: "Root"
            children:
              - page: "Page 1"
              - page: "Page 2"

      - clone:
          from: original
          name: copy1
          title: "First Copy"

      - clone:
          from: original
          name: copy2
          title: "Second Copy"
      """

      directives = Oli.Scenarios.DirectiveParser.parse_yaml!(yaml)
      result = Scenarios.execute(directives, author: author)

      # Verify all projects exist
      assert result.errors == []
      assert Map.has_key?(result.state.projects, "original")
      assert Map.has_key?(result.state.projects, "copy1")
      assert Map.has_key?(result.state.projects, "copy2")

      # Verify titles
      assert result.state.projects["original"].project.title == "Original Project"
      assert result.state.projects["copy1"].project.title == "First Copy"
      assert result.state.projects["copy2"].project.title == "Second Copy"
    end
  end
end
