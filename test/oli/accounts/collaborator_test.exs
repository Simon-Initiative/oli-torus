defmodule Oli.Accounts.CollaboratorTest do
  use Oli.DataCase

  alias Oli.Authoring.Collaborators
  alias Oli.Repo

  import Ecto.Query, warn: false
  import ExUnit.Assertions
  import Oli.Factory
  import Swoosh.TestAssertions

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

    test "invite_collaborator/3 for a new author: creates author, adds author to the given project (as :pending_confirmation with contributor role), creates invitation token and delivers email invitation" do
      project = insert(:project)

      {:ok, author_project} =
        Collaborators.invite_collaborator(
          "some_author@gmail.com",
          "non_existing_author@gmail.com",
          project.slug
        )

      # author is created and added to the project
      invited_author = Oli.Accounts.get_author!(author_project.author_id)

      assert invited_author.email == "non_existing_author@gmail.com"
      assert author_project.project_id == project.id
      assert author_project.status == :pending_confirmation

      assert author_project.project_role_id ==
               Oli.Authoring.Authors.ProjectRole.role_id().contributor

      # invitation author_token is created
      context = "collaborator_invitation:#{project.slug}"

      assert from(at in Oli.Accounts.AuthorToken,
               where:
                 at.author_id == ^invited_author.id and at.context == ^context and
                   at.sent_to == "non_existing_author@gmail.com"
             )
             |> Repo.one()

      # and email is sent
      assert_email_sent(
        to: "non_existing_author@gmail.com",
        subject: "You were invited as a collaborator to \"#{project.title}\""
      )
    end

    test "invite_collaborator/3 for an existing author: adds author to the given project (as :pending_confirmation with contributor role), creates invitation token and delivers email invitation" do
      project = insert(:project)
      existing_author = insert(:author)

      {:ok, author_project} =
        Collaborators.invite_collaborator(
          "some_author@gmail.com",
          existing_author.email,
          project.slug
        )

      # author is added to the project
      assert author_project.author_id == existing_author.id
      assert author_project.project_id == project.id
      assert author_project.status == :pending_confirmation

      assert author_project.project_role_id ==
               Oli.Authoring.Authors.ProjectRole.role_id().contributor

      # invitation author_token is created
      context = "collaborator_invitation:#{project.slug}"

      assert from(at in Oli.Accounts.AuthorToken,
               where:
                 at.author_id == ^existing_author.id and at.context == ^context and
                   at.sent_to == ^existing_author.email
             )
             |> Repo.one()

      # and email is sent
      assert_email_sent(
        to: existing_author.email,
        subject: "You were invited as a collaborator to \"#{project.title}\""
      )
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
