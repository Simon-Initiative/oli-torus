defmodule Oli.Scenarios.EditPageTest do
  use Oli.DataCase

  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.DirectiveParser

  # Helper to get the latest revision for a page by its original or new title
  defp get_latest_page_revision(project, original_title) do
    # Try to find by original title first
    case Map.get(project.rev_by_title, original_title) do
      nil ->
        # Title might have changed, look for the page by checking all revisions
        # In our tests, we know which pages had their titles changed
        # For "Page 1" -> "Updated Page 1", etc.
        updated_titles = %{
          "Page 1" => "Updated Page 1",
          "Format Test" => "Formatted Content",
          "Test Page" => "Multi-Block Page",
          "Evolving Page" => "Version 2",
          "Assessment" => "Graded Assessment"
        }
        
        new_title = Map.get(updated_titles, original_title, original_title)
        Map.get(project.rev_by_title, new_title)
        
      revision ->
        # Found it directly
        revision
    end
  end

  describe "edit_page directive" do
    test "edits an existing page with TorusDoc YAML content" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Page 1"
              - page: "Page 2"

      - edit_page:
          project: test_project
          page: "Page 1"
          content: |
            title: "Updated Page 1"
            graded: false
            blocks:
              - type: prose
                body_md: |
                  # New Content
                  
                  This is the updated content for Page 1.
                  
                  It has been edited via the edit_page directive.
              - type: prose
                body_md: |
                  ## Second Section
                  
                  Additional content here.
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Get the project and verify the page was edited
      project = Map.get(result.state.projects, "test_project")
      assert project != nil

      # Get the latest revision for the page
      page_revision = get_latest_page_revision(project, "Page 1")
      assert page_revision != nil

      # Verify the title was updated
      assert page_revision.title == "Updated Page 1"

      # Verify the content was updated
      assert page_revision.content["model"] != nil

      # The model should be a list of content blocks
      model = page_revision.content["model"]

      # Check if we have the expected content structure
      # The content should have been parsed into paragraphs, headings, etc
      assert is_list(model)
      assert length(model) > 0

      # The content should contain the text we added
      model_json = Jason.encode!(model)
      assert model_json =~ "New Content"
      assert model_json =~ "Second Section"
    end

    test "fails when project doesn't exist" do
      yaml = """
      - edit_page:
          project: nonexistent_project
          page: "Page 1"
          content: |
            title: "Test"
            blocks:
              - type: prose
                body_md: "Test content"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert length(result.errors) > 0
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "Project 'nonexistent_project' not found"
    end

    test "fails when page doesn't exist in project" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Page 1"

      - edit_page:
          project: test_project
          page: "Nonexistent Page"
          content: |
            title: "Test"
            blocks:
              - type: prose
                body_md: "Test content"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert length(result.errors) > 0
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "Page 'Nonexistent Page' not found in project"
    end

    test "handles multiple prose blocks" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Test Page"

      - edit_page:
          project: test_project
          page: "Test Page"
          content: |
            title: "Multi-Block Page"
            blocks:
              - type: prose
                body_md: "First block"
              - type: prose
                body_md: "Second block"
              - type: prose
                body_md: "Third block"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      project = Map.get(result.state.projects, "test_project")
      page_revision = get_latest_page_revision(project, "Test Page")

      assert page_revision.title == "Multi-Block Page"
      assert length(page_revision.content["model"]) == 3
    end

    test "preserves markdown formatting in content" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Format Test"

      - edit_page:
          project: test_project
          page: "Format Test"
          content: |
            title: "Formatted Content"
            blocks:
              - type: prose
                body_md: |
                  # Heading 1
                  
                  **Bold text** and *italic text*
                  
                  - List item 1
                  - List item 2
                  
                  `inline code` and:
                  
                  ```elixir
                  def hello do
                    "world"
                  end
                  ```
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      project = Map.get(result.state.projects, "test_project")
      page_revision = get_latest_page_revision(project, "Format Test")

      assert page_revision.title == "Formatted Content"

      # The content should be converted to Torus JSON format
      model = page_revision.content["model"]
      assert is_list(model)
      assert length(model) > 0

      # Verify the content contains our formatted text
      model_json = Jason.encode!(model)
      assert model_json =~ "Heading 1"
      assert model_json =~ "Bold text"
      assert model_json =~ "italic text"
      assert model_json =~ "List item"
      assert model_json =~ "hello"
    end

    test "can edit page multiple times" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Evolving Page"

      - edit_page:
          project: test_project
          page: "Evolving Page"
          content: |
            title: "Version 1"
            blocks:
              - type: prose
                body_md: "First version"

      - edit_page:
          project: test_project
          page: "Evolving Page"
          content: |
            title: "Version 2"
            blocks:
              - type: prose
                body_md: "Second version with more content"
              - type: prose
                body_md: "Additional block"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      project = Map.get(result.state.projects, "test_project")

      # Get the latest revision after multiple edits
      page_revision = get_latest_page_revision(project, "Evolving Page")

      # Should have the content from the second edit
      assert page_revision.title == "Version 2"
      assert length(page_revision.content["model"]) == 2
    end

    test "handles graded page attribute" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Assessment"

      - edit_page:
          project: test_project
          page: "Assessment"
          content: |
            title: "Graded Assessment"
            graded: true
            blocks:
              - type: prose
                body_md: "This is a graded page"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      project = Map.get(result.state.projects, "test_project")
      page_revision = get_latest_page_revision(project, "Assessment")

      assert page_revision.title == "Graded Assessment"
      assert page_revision.graded == true
    end
  end
end
