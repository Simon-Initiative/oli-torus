defmodule Oli.TorusDocTest do
  use Oli.DataCase

  alias Oli.TorusDoc
  alias Oli.Authoring.Clone
  alias Oli.Publishing

  describe "project directive - clone" do
    setup do
      # Create a test project with some resources
      project_map = Oli.Seeder.base_project_with_resource2()

      # The publication is already created by the seeder
      publication = Publishing.project_working_publication(project_map.project.slug)

      Map.put(project_map, :publication, publication)
    end

    test "processes clone directive with valid project and author", %{
      project: project,
      author: author
    } do
      yaml = """
      type: project_directive
      directive: clone
      from: #{project.slug}
      to: new-cloned-project
      """

      {:ok, result} = TorusDoc.process(yaml, %{author: author})

      assert result.type == "clone_result"
      assert result.success == true
      assert result.source_project == project.slug
      assert result.cloned_project != nil
      assert result.message =~ "Successfully cloned project"

      # Verify the project was actually cloned
      clones = Clone.existing_clones(project.slug, author)
      assert length(clones) > 0
    end

    test "fails clone directive without author context", %{project: project} do
      yaml = """
      type: project_directive
      directive: clone
      from: #{project.slug}
      to: new-cloned-project
      """

      {:error, message} = TorusDoc.process(yaml)
      assert message == "Clone directive requires author context"
    end

    test "fails clone directive without from field" do
      yaml = """
      type: project_directive
      directive: clone
      to: new-cloned-project
      """

      {:error, message} = TorusDoc.process(yaml, %{author: %{id: 1}})
      assert message == "Clone directive requires 'from' field with source project slug"
    end

    test "fails clone directive without to field", %{project: project} do
      yaml = """
      type: project_directive
      directive: clone
      from: #{project.slug}
      """

      {:error, message} = TorusDoc.process(yaml, %{author: %{id: 1}})
      assert message == "Clone directive requires 'to' field with target project slug"
    end

    test "fails clone directive with non-existent project", %{author: author} do
      yaml = """
      type: project_directive
      directive: clone
      from: non-existent-project
      to: new-cloned-project
      """

      {:error, message} = TorusDoc.process(yaml, %{author: author})
      assert message =~ "Failed to clone project"
    end

    test "fails with unknown project directive" do
      yaml = """
      type: project_directive
      directive: unknown_directive
      """

      {:error, message} = TorusDoc.process(yaml)

      assert message ==
               "Unknown project directive: unknown_directive. Supported directives: clone"
    end

    test "fails when directive field is missing" do
      yaml = """
      type: project_directive
      from: some-project
      to: another-project
      """

      {:error, message} = TorusDoc.process(yaml)
      assert message == "Project directive must have a 'directive' field"
    end
  end

  describe "page document processing" do
    test "processes page documents correctly" do
      yaml = """
      type: page
      id: test-page
      title: Test Page
      blocks:
        - type: prose
          body_md: "# Hello World"
      """

      {:ok, result} = TorusDoc.process(yaml)

      assert result["type"] == "Page"
      assert result["title"] == "Test Page"
      assert result["content"]["model"] != nil
    end

    test "page processing still works with context" do
      yaml = """
      type: page
      id: test-page
      title: Test Page
      blocks:
        - type: prose
          body_md: "Some content"
      """

      {:ok, result} = TorusDoc.process(yaml, %{author: %{id: 1}})

      assert result["type"] == "Page"
    end
  end

  describe "document type validation" do
    test "fails with unknown document type" do
      yaml = """
      type: unknown_type
      some_field: some_value
      """

      {:error, message} = TorusDoc.process(yaml)

      assert message ==
               "Unknown document type: unknown_type. Expected 'page' or 'project_directive'"
    end

    test "fails when type field is missing" do
      yaml = """
      some_field: some_value
      another_field: another_value
      """

      {:error, message} = TorusDoc.process(yaml)
      assert message == "Document must have a 'type' field"
    end

    test "fails with invalid YAML" do
      yaml = """
      invalid: yaml: content
      : bad formatting
      """

      {:error, message} = TorusDoc.process(yaml)
      assert message =~ "YAML parsing failed"
    end
  end
end
