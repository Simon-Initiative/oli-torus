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
          Oli.Resources.ResourceType.get_id_by_type("tag")
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
                 Oli.Resources.ResourceType.get_id_by_type("tag")
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
                 Oli.Resources.ResourceType.get_id_by_type("tag")
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
          Oli.Resources.ResourceType.get_id_by_type("tag")
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
          Oli.Resources.ResourceType.get_id_by_type("tag")
        )

      assert length(revisions) == 1
      assert Enum.at(revisions, 0).resource_id == hard.revision.resource_id
    end
  end
end
