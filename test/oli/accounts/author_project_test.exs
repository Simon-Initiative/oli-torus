defmodule Oli.Accounts.AuthorProjectTest do
  use Oli.DataCase
  alias Oli.AuthorsProjects
  import ExUnit.Assertions

  setup [:author_project_fixture]

    describe "add author to projects" do
      test "adding an author creates an association between the project and the author", %{project: project} do
        author2 = author_fixture()
        {:ok, _author_project} = AuthorsProjects.create_author_project(author2.email, project.slug)
        assert Enum.member?(Repo.preload(author2, [:projects]).projects, project)
        assert Enum.member?(Repo.preload(project, [:authors]).authors, author2)
      end

      test "adds author as contributor once a project already has an owner", %{project: project} do
        author2 = author_fixture()
        {:ok, author_project} = AuthorsProjects.create_author_project(author2.email, project.slug)
        assert Repo.preload(author_project, [:project_role]).project_role.type == "contributor"
      end

      test "cannot add the same author twice", %{author: author, project: project} do
        catch_error AuthorsProjects.create_author_project(author.email, project.slug)
      end
    end

    describe "remove author from project" do
      test "removes the association between author and project", %{project: project} do
        # add second author
        author2 = author_fixture()
        AuthorsProjects.create_author_project(author2.email, project.slug)
        # remove second author
        AuthorsProjects.delete_author_project(author2.email, project.slug)

        refute Enum.member?(Repo.preload(author2, [:projects]).projects, project)
        refute Enum.member?(Repo.preload(project, [:authors]).authors, author2)
      end

      test "cannot remove the owner", %{author: author, project: project} do
        assert {:error, _} = AuthorsProjects.delete_author_project(author.email, project.slug)
      end
    end

end
