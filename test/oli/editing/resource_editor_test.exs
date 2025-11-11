defmodule Oli.Editing.ResourceEditorTest do
  use Oli.DataCase

  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Accounts.{SystemRole, Author}
  alias Oli.Repo

  describe "tag editing" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_tag("Easy", :easy)
      |> Seeder.create_tag("Hard", :hard)
    end

    test "list/2 lists both tags", %{author: author, project: project, easy: easy, hard: hard} do
      {:ok, revisions} =
        ResourceEditor.list(
          project.slug,
          author,
          Oli.Resources.ResourceType.id_for_tag()
        )

      assert length(revisions) == 2
      assert Enum.at(revisions, 0).resource_id == easy.revision.resource_id
      assert Enum.at(revisions, 1).resource_id == hard.revision.resource_id
    end

    test "list/2 fails when project does not exist", %{
      author: author
    } do
      assert {:error, {:not_found}} ==
               ResourceEditor.list(
                 "does_not_exist",
                 author,
                 Oli.Resources.ResourceType.id_for_tag()
               )
    end

    test "list/2 fails when author does not have access", %{
      project: project
    } do
      {:ok, author} =
        Author.noauth_changeset(%Author{}, %{
          email: "newone@test.com",
          given_name: "First",
          family_name: "Last",
          provider: "foo",
          system_role_id: SystemRole.role_id().author
        })
        |> Repo.insert()

      assert {:error, {:not_authorized}} ==
               ResourceEditor.list(
                 project.slug,
                 author,
                 Oli.Resources.ResourceType.id_for_tag()
               )
    end

    test "edit/4 fails when project does not exist", %{
      author: author,
      easy: easy
    } do
      assert {:error, {:not_found}} ==
               ResourceEditor.edit("does_not_exist", easy.revision.resource_id, author, %{
                 "title" => "test"
               })
    end

    test "edit/4 fails when tag resource id does not exist", %{
      author: author,
      project: project
    } do
      assert {:error, {:not_found}} ==
               ResourceEditor.edit(project.slug, 22222, author, %{
                 "title" => "test"
               })
    end

    test "edit/4 fails when author does not have access", %{
      project: project,
      easy: easy
    } do
      {:ok, author} =
        Author.noauth_changeset(%Author{}, %{
          email: "newone@test.com",
          given_name: "First",
          family_name: "Last",
          provider: "foo",
          system_role_id: SystemRole.role_id().author
        })
        |> Repo.insert()

      assert {:error, {:not_authorized}} ==
               ResourceEditor.edit(project.slug, easy.revision.resource_id, author, %{
                 "title" => "test"
               })
    end

    test "edit/4 allows title editing", %{author: author, project: project, easy: easy} do
      {:ok, _} =
        ResourceEditor.edit(project.slug, easy.revision.resource_id, author, %{
          "title" => "updated title"
        })

      revision =
        Oli.Publishing.AuthoringResolver.from_resource_id(project.slug, easy.revision.resource_id)

      refute revision.id == easy.revision.id
      assert revision.title == "updated title"

      {:ok, revisions} =
        ResourceEditor.list(
          project.slug,
          author,
          Oli.Resources.ResourceType.id_for_tag()
        )

      assert length(revisions) == 2
      assert Enum.at(revisions, 0).resource_id == easy.revision.resource_id
    end

    test "deleting a tag makes it inaccessible via list/2", %{
      author: author,
      project: project,
      easy: easy,
      hard: hard
    } do
      {:ok, _} =
        ResourceEditor.edit(project.slug, easy.revision.resource_id, author, %{
          "deleted" => true
        })

      revision =
        Oli.Publishing.AuthoringResolver.from_resource_id(project.slug, easy.revision.resource_id)

      refute revision.id == easy.revision.id
      assert revision.deleted == true

      {:ok, revisions} =
        ResourceEditor.list(
          project.slug,
          author,
          Oli.Resources.ResourceType.id_for_tag()
        )

      assert length(revisions) == 1
      assert Enum.at(revisions, 0).resource_id == hard.revision.resource_id
    end

    test "get_or_create_tag/3 creates a new tag when it doesn't exist", %{
      author: author,
      project: project
    } do
      {:ok, tag} = ResourceEditor.get_or_create_tag(project.slug, author, "NewTag")

      assert tag.title == "NewTag"
      assert tag.resource_id != nil

      # Verify it was actually created by listing all tags
      {:ok, revisions} =
        ResourceEditor.list(
          project.slug,
          author,
          Oli.Resources.ResourceType.id_for_tag()
        )

      assert length(revisions) == 3
      assert Enum.any?(revisions, fn rev -> rev.resource_id == tag.resource_id end)
    end

    test "get_or_create_tag/3 returns existing tag when it already exists (exact match)", %{
      author: author,
      project: project,
      easy: easy
    } do
      # Try to create a tag with the same title as "Easy"
      {:ok, tag} = ResourceEditor.get_or_create_tag(project.slug, author, "Easy")

      # Should return the existing tag, not create a new one
      assert tag.resource_id == easy.revision.resource_id
      assert tag.title == "Easy"

      # Verify no new tag was created
      {:ok, revisions} =
        ResourceEditor.list(
          project.slug,
          author,
          Oli.Resources.ResourceType.id_for_tag()
        )

      assert length(revisions) == 2
    end

    test "get_or_create_tag/3 returns existing tag with case-insensitive matching", %{
      author: author,
      project: project,
      easy: easy
    } do
      # Try to create a tag with different case
      {:ok, tag_lower} = ResourceEditor.get_or_create_tag(project.slug, author, "easy")

      assert tag_lower.resource_id == easy.revision.resource_id
      assert tag_lower.title == "Easy"

      {:ok, tag_upper} = ResourceEditor.get_or_create_tag(project.slug, author, "EASY")

      assert tag_upper.resource_id == easy.revision.resource_id
      assert tag_upper.title == "Easy"

      {:ok, tag_mixed} = ResourceEditor.get_or_create_tag(project.slug, author, "EaSy")

      assert tag_mixed.resource_id == easy.revision.resource_id
      assert tag_mixed.title == "Easy"

      # Verify no new tags were created
      {:ok, revisions} =
        ResourceEditor.list(
          project.slug,
          author,
          Oli.Resources.ResourceType.id_for_tag()
        )

      assert length(revisions) == 2
    end

    test "get_or_create_tag/3 fails when project does not exist", %{
      author: author
    } do
      assert {:error, {:not_found}} ==
               ResourceEditor.get_or_create_tag("does_not_exist", author, "SomeTag")
    end

    test "get_or_create_tag/3 fails when author does not have access", %{
      project: project
    } do
      {:ok, author} =
        Author.noauth_changeset(%Author{}, %{
          email: "unauthorized@test.com",
          given_name: "Unauthorized",
          family_name: "User",
          provider: "foo",
          system_role_id: SystemRole.role_id().author
        })
        |> Repo.insert()

      assert {:error, {:not_authorized}} ==
               ResourceEditor.get_or_create_tag(project.slug, author, "SomeTag")
    end

    test "get_or_create_tag/3 handles multiple duplicate attempts correctly", %{
      author: author,
      project: project
    } do
      # Create a new tag
      {:ok, tag1} = ResourceEditor.get_or_create_tag(project.slug, author, "Unique")
      original_resource_id = tag1.resource_id

      # Try to create it multiple times with different cases
      {:ok, tag2} = ResourceEditor.get_or_create_tag(project.slug, author, "unique")
      {:ok, tag3} = ResourceEditor.get_or_create_tag(project.slug, author, "UNIQUE")
      {:ok, tag4} = ResourceEditor.get_or_create_tag(project.slug, author, "UnIqUe")

      # All should return the same tag
      assert tag2.resource_id == original_resource_id
      assert tag3.resource_id == original_resource_id
      assert tag4.resource_id == original_resource_id

      # Verify only one tag was created
      {:ok, revisions} =
        ResourceEditor.list(
          project.slug,
          author,
          Oli.Resources.ResourceType.id_for_tag()
        )

      assert length(revisions) == 3
      assert Enum.count(revisions, fn rev -> rev.resource_id == original_resource_id end) == 1
    end
  end
end
