defmodule Oli.Accounts.CollaboratorTest do
  use Oli.DataCase

  alias Oli.Auditing.LogEvent
  alias Oli.Authoring.Audited
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
      {:ok, _collab} = Audited.add_collaborator(audit_context(), author2, project)
      assert Enum.member?(Repo.preload(author2, [:projects]).projects, project)
      assert Enum.member?(Repo.preload(project, [:authors]).authors, author2)

      assert [event] = collaborator_events(project)
      assert event.affected_author_id == author2.id

      assert event.changes == %{
               "status" => %{"operation" => "set", "after" => "accepted"},
               "role" => %{"operation" => "set", "after" => "contributor"}
             }
    end

    test "adds author as contributor once a project already has an owner", %{project: project} do
      author2 = author_fixture()
      {:ok, collaborator} = Audited.add_collaborator(audit_context(), author2, project)
      assert Repo.preload(collaborator, [:project_role]).project_role.type == "contributor"
    end

    test "cannot add the same author twice", %{author: author, project: project} do
      assert {:error, _} = Audited.add_collaborator(audit_context(), author, project)
      assert collaborator_events(project) == []
    end

    test "invite_collaborator/4 for a new author: creates author, adds author to the given project (as :pending_confirmation with contributor role), creates invitation token and delivers email invitation" do
      project = insert(:project)

      {:ok, author_project} =
        Audited.invite_collaborator(
          Oli.Auditing.Context.for_actor(insert(:author), source: :ui),
          "Inviter Author",
          "inviter@gmail.com",
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

      # and email is sent with correct reply_to header
      assert_email_sent(
        to: "non_existing_author@gmail.com",
        subject: "You were invited as a collaborator to \"#{project.title}\"",
        reply_to: {"Inviter Author", "inviter@gmail.com"}
      )
    end

    test "invite_collaborator/4 for an existing author: adds author to the given project (as :pending_confirmation with contributor role), creates invitation token and delivers email invitation" do
      project = insert(:project)
      existing_author = insert(:author)

      {:ok, author_project} =
        Audited.invite_collaborator(
          Oli.Auditing.Context.for_actor(insert(:author), source: :ui),
          "Inviter Author",
          "inviter@gmail.com",
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

      # and email is sent with correct reply_to header
      assert_email_sent(
        to: existing_author.email,
        subject: "You were invited as a collaborator to \"#{project.title}\"",
        reply_to: {"Inviter Author", "inviter@gmail.com"}
      )
    end
  end

  describe "remove author from project" do
    test "removes the association between author and project", %{project: project} do
      # add second author
      author2 = author_fixture()
      {:ok, _} = Audited.add_collaborator(audit_context(), author2, project)
      # remove second author
      assert {:ok, _} = remove(author2.email, project.slug)

      refute Enum.member?(Repo.preload(author2, [:projects]).projects, project)
      refute Enum.member?(Repo.preload(project, [:authors]).authors, author2)

      assert [_added, removed] = collaborator_events(project)
      assert removed.affected_author_id == author2.id

      assert removed.changes == %{
               "status" => %{"operation" => "set", "before" => "accepted"},
               "role" => %{"operation" => "set", "before" => "contributor"}
             }
    end

    test "cannot remove the owner", %{author: author, project: project} do
      assert {:error, "That author is the project owner."} = remove(author.email, project.slug)
      assert Enum.member?(Repo.preload(project, [:authors]).authors, author)
      assert collaborator_events(project) == []
    end
  end

  describe "invitation answers" do
    setup %{project: project} do
      invited = insert(:author)

      {:ok, _} =
        Audited.invite_collaborator(
          audit_context(),
          "Inviter",
          "inviter@example.edu",
          invited.email,
          project.slug
        )

      %{invited: invited}
    end

    test "the invited author accepts, as actor of the change", %{
      invited: invited,
      project: project
    } do
      context = Oli.Auditing.Context.for_actor(invited, source: :ui)

      assert {:ok, %{status: :accepted}} =
               Audited.respond_to_invitation(context, {invited.id, project.id, :accepted})

      assert [_invited, accepted] = collaborator_events(project)
      assert accepted.author_id == invited.id
      assert accepted.affected_author_id == invited.id

      assert accepted.changes == %{
               "status" => %{
                 "operation" => "set",
                 "before" => "pending_confirmation",
                 "after" => "accepted"
               }
             }

      # A second answer finds nothing pending and records nothing.
      assert {:ok, %{status: :accepted}} =
               Audited.respond_to_invitation(context, {invited.id, project.id, :rejected})

      assert length(collaborator_events(project)) == 2
    end

    test "rejection is recorded", %{invited: invited, project: project} do
      context = Oli.Auditing.Context.for_actor(invited, source: :ui)

      assert {:ok, %{status: :rejected}} =
               Audited.respond_to_invitation(context, {invited.id, project.id, :rejected})

      assert [_invited, rejected] = collaborator_events(project)
      assert rejected.changes["status"]["after"] == "rejected"
    end
  end

  defp remove(email, project_slug) do
    Ecto.Multi.new()
    |> Audited.remove_collaborator_multi(:removed, audit_context(), {email, project_slug})
    |> Repo.transaction()
    |> case do
      {:ok, %{removed: removed}} -> {:ok, removed}
      {:error, :removed, reason, _} -> {:error, reason}
    end
  end

  defp collaborator_events(project) do
    Repo.all(
      from(e in LogEvent,
        where: e.event_type == :project_collaborator_changed and e.project_id == ^project.id,
        order_by: e.id
      )
    )
  end
end
