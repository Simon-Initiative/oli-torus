defmodule Oli.Accounts.CollaboratorTest do
  use Oli.DataCase
  alias Oli.Authoring.Collaborators
  import ExUnit.Assertions

  setup [:author_project_fixture]

  describe "add author to projects" do
    test "adding an author creates an association between the project and the author", %{
      project: project
    } do
      author2 = author_fixture()
      {:ok, _collab} = Collaborators.add_collaborator(author2.email, project.slug)
      assert Enum.member?(Repo.preload(author2, [:projects]).projects, project)
      assert Enum.member?(Repo.preload(project, [:authors]).authors, author2)
    end

    test "adds author as contributor once a project already has an owner", %{project: project} do
      author2 = author_fixture()
      {:ok, collaborator} = Collaborators.add_collaborator(author2.email, project.slug)
      assert Repo.preload(collaborator, [:project_role]).project_role.type == "contributor"
    end

    test "cannot add the same author twice", %{author: author, project: project} do
      assert {:error, _} = Collaborators.add_collaborator(author.email, project.slug)
    end
  end

  describe "remove author from project" do
    test "removes the association between author and project", %{project: project} do
      # add second author
      author2 = author_fixture()
      Collaborators.add_collaborator(author2.email, project.slug)
      # remove second author
      Collaborators.remove_collaborator(author2.email, project.slug)

      refute Enum.member?(Repo.preload(author2, [:projects]).projects, project)
      refute Enum.member?(Repo.preload(project, [:authors]).authors, author2)
    end

    test "cannot remove the owner", %{author: author, project: project} do
      assert {:error, _} = Collaborators.remove_collaborator(author.email, project.slug)
    end
  end
end
