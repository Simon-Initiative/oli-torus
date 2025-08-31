defmodule Oli.Scenarios.DSLTest do
  use Oli.DataCase
  
  alias Oli.Scenarios.{Engine, TestHelpers}
  alias Oli.Scenarios.DirectiveTypes.ExecutionResult

  describe "flexible course specification DSL" do
    test "can create a simple project and section" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
              - page: "Page 2"
      
      - section:
          name: "test_section"
          from: "test_project"
          title: "Test Section"
      """
      
      result = TestHelpers.execute_yaml(yaml)
      
      assert %ExecutionResult{errors: []} = result
      assert project = TestHelpers.get_project(result, "test_project")
      assert section = TestHelpers.get_section(result, "test_section")
      
      assert project.project.title == "Test Project"
      assert section.title == "Test Section"
    end
    
    test "can remix content between projects and sections" do
      yaml = """
      - project:
          name: "source"
          title: "Source Project"
          root:
            children:
              - container: "Unit A"
                children:
                  - page: "Lesson 1"
                  - page: "Lesson 2"
      
      - project:
          name: "dest"
          title: "Destination Project"
          root:
            children:
              - page: "Welcome"
      
      - section:
          name: "main_section"
          from: "dest"
      
      - remix:
          source: "source"
          target: "main_section"
          resource: "Unit A"
          into: "root"
      """
      
      result = TestHelpers.execute_yaml(yaml)
      
      assert %ExecutionResult{errors: []} = result
      assert TestHelpers.get_section(result, "main_section")
      # Remixed content would be verified through structure assertions
    end
    
    test "can publish changes to projects" do
      yaml = """
      - project:
          name: "my_project"
          title: "My Project"
          root:
            children:
              - page: "Original Page"
      
      - publish_changes:
          target: "my_project"
          description: "Adding new content"
          ops:
            - add_page:
                title: "New Page"
                parent: "root"
      """
      
      result = TestHelpers.execute_yaml(yaml)
      
      assert %ExecutionResult{errors: []} = result
      project = TestHelpers.get_project(result, "my_project")
      
      # Verify the new page was added
      assert Map.has_key?(project.id_by_title, "New Page")
    end
    
    @tag :skip
    test "can verify section structure" do
      yaml = """
      - project:
          name: "project"
          title: "Test Project"
          root:
            children:
              - page: "Page A"
              - container: "Unit"
                children:
                  - page: "Page B"
      
      - section:
          name: "section"
          from: "project"
      
      - verify:
          target: "section"
          structure:
            root:
              children:
                - page: "Page A"
                - container: "Unit"
                  children:
                    - page: "Page B"
      """
      
      result = TestHelpers.execute_yaml(yaml)
      
      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed == true
      assert verification.target == "section"
    end
    
    test "can create and enroll users" do
      yaml = """
      - user:
          name: "instructor"
          type: "instructor"
          email: "instructor@test.edu"
      
      - user:
          name: "student"
          type: "student"
          email: "student@test.edu"
      
      - project:
          name: "course"
          title: "Test Course"
          root:
            children:
              - page: "Content"
      
      - section:
          name: "section"
          from: "course"
      
      - enroll:
          user: "instructor"
          section: "section"
          role: "instructor"
      
      - enroll:
          user: "student"
          section: "section"
          role: "student"
      """
      
      result = TestHelpers.execute_yaml(yaml)
      
      assert %ExecutionResult{errors: []} = result
      assert Engine.get_user(result.state, "instructor")
      assert Engine.get_user(result.state, "student")
      assert Engine.get_section(result.state, "section")
    end
    
    @tag :skip
    test "can build scenarios programmatically" do
      # Build a scenario using helper functions
      scenario = TestHelpers.build_scenario([
        TestHelpers.simple_project_yaml("proj1", "Project 1"),
        TestHelpers.simple_section_yaml("sect1", "proj1"),
        TestHelpers.verify_yaml("sect1", """
          root:
            children:
              - page: "Page 1"
              - page: "Page 2"
        """)
      ])
      
      result = TestHelpers.execute_yaml(scenario)
      
      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed == true
    end
    
    test "reports errors for invalid references" do
      yaml = """
      - section:
          name: "orphan_section"
          from: "nonexistent_project"
      """
      
      result = TestHelpers.execute_yaml(yaml)
      
      assert %ExecutionResult{errors: errors} = result
      assert length(errors) > 0
      assert {_directive, reason} = hd(errors)
      assert reason =~ "not found"
    end
    
    test "supports multiple projects in single file" do
      yaml = """
      - project:
          name: "project1"
          title: "First Project"
          root:
            children:
              - page: "P1 Page"
      
      - project:
          name: "project2"
          title: "Second Project"
          root:
            children:
              - page: "P2 Page"
      
      - project:
          name: "project3"
          title: "Third Project"
          root:
            children:
              - page: "P3 Page"
      """
      
      result = TestHelpers.execute_yaml(yaml)
      
      assert %ExecutionResult{errors: []} = result
      assert TestHelpers.get_project(result, "project1")
      assert TestHelpers.get_project(result, "project2")
      assert TestHelpers.get_project(result, "project3")
    end
  end
end