defmodule Oli.Authoring.AuditedProjectsTest do
  # The audit failure tests add a trigger to the audit table, which locks it until the test ends.
  use Oli.DataCase, async: false

  import ExUnit.CaptureLog
  import Oli.Factory

  alias Oli.Auditing.{Context, LogEvent}
  alias Oli.Authoring.Audited
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing
  alias Oli.Publishing.Publications.Publication

  setup do
    author = insert(:author)
    %{author: author, context: Context.for_actor(author, source: :ui)}
  end

  describe "project lifecycle" do
    test "creation records the creator as the owner", %{author: author, context: context} do
      assert {:ok, %{project: project}} = Audited.create_project(context, "Biology", author)

      assert [created] = events(project, :project_created)
      assert created.author_id == author.id
      assert created.affected_author_id == author.id
      assert created.entity_type == :project
      assert created.details == %{"project_title" => "Biology"}
      assert created.event_key == "project:#{project.id}:created"

      # The initial working publication is bookkeeping, not a publication.
      assert events(project, :project_published) == []
    end

    test "duplication records the source project and the new owner", %{
      author: author,
      context: context
    } do
      {:ok, %{project: source}} = Audited.create_project(context, "Biology", author)
      copier = insert(:author)

      assert {:ok, copy} =
               Audited.duplicate_project(
                 Context.for_actor(copier, source: :ui),
                 source.slug,
                 copier
               )

      assert [duplicated] = events(copy, :project_duplicated)
      assert duplicated.affected_author_id == copier.id
      assert duplicated.details["source_project_id"] == source.id

      assert duplicated.refs == [
               %{"role" => "source", "type" => "project", "id" => source.id, "label" => "Biology"}
             ]
    end

    test "deletion is recorded once", %{author: author, context: context} do
      {:ok, %{project: project}} = Audited.create_project(context, "Biology", author)

      assert {:ok, %Project{status: :deleted}} = Audited.delete_project(context, project.id)
      assert {:ok, %Project{status: :deleted}} = Audited.delete_project(context, project.id)

      assert [deleted] = events(project, :project_deleted)
      assert deleted.details == %{"project_title" => "Biology"}
    end

    test "an import inside a rolled-back ingest leaves no project and no event", %{
      author: author,
      context: context
    } do
      title = "Imported #{System.unique_integer([:positive])}"

      assert {:error, :ingest_failed} =
               Repo.transaction(fn ->
                 {:ok, _} = Audited.import_project(context, title, author, :naive, %{})
                 Repo.rollback(:ingest_failed)
               end)

      refute Repo.get_by(Project, title: title)

      assert Repo.all(from(e in LogEvent, where: e.event_type == :project_imported)) == []
    end

    test "an audit failure rolls the creation back", %{author: author, context: context} do
      reject_audit_inserts()
      title = "Rejected #{System.unique_integer([:positive])}"

      capture_log(fn ->
        assert {:error, _} = Audited.create_project(context, title, author)
      end)

      refute Repo.get_by(Project, title: title)
    end
  end

  describe "publication" do
    setup %{author: author, context: context} do
      {:ok, %{project: project}} = Audited.create_project(context, "Biology", author)
      %{project: project}
    end

    test "records the resulting and previous publications", %{
      author: author,
      context: context,
      project: project
    } do
      {:ok, first} = Oli.Publishing.Audited.publish_project(context, project, "First", author.id)

      {:ok, second} =
        Oli.Publishing.Audited.publish_project(context, project, "Second", author.id)

      assert [first_event, second_event] = events(project, :project_published)

      assert first_event.details == %{
               "project_title" => "Biology",
               "publication_id" => first.id,
               "description" => "First",
               "version" => version(first)
             }

      assert first_event.refs == [
               %{
                 "role" => "resulting",
                 "type" => "publication",
                 "id" => first.id,
                 "label" => version(first)
               }
             ]

      assert [
               %{"role" => "resulting", "id" => second_id},
               %{"role" => "previous", "id" => previous_id}
             ] = second_event.refs

      assert {second_id, previous_id} == {second.id, first.id}
    end

    test "an audit failure leaves the working publication unpublished", %{
      author: author,
      context: context,
      project: project
    } do
      working = Publishing.project_working_publication(project.slug)
      reject_audit_inserts()

      capture_log(fn ->
        assert {:error, _} =
                 Oli.Publishing.Audited.publish_project(context, project, "Rejected", author.id)
      end)

      assert %Publication{published: nil} = Repo.get!(Publication, working.id)
      assert Publishing.project_working_publication(project.slug).id == working.id
    end
  end

  defp version(%Publication{} = publication),
    do: "#{publication.edition}.#{publication.major}.#{publication.minor}"

  defp events(project, event_type) do
    Repo.all(
      from(e in LogEvent,
        where: e.event_type == ^event_type and e.project_id == ^project.id,
        order_by: e.id
      )
    )
  end

  defp reject_audit_inserts do
    Repo.query!("""
    CREATE FUNCTION pg_temp.reject_audit_insert() RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'audit insert rejected by test';
    END;
    $$ LANGUAGE plpgsql
    """)

    Repo.query!("""
    CREATE TRIGGER reject_audit_insert BEFORE INSERT ON audit_log_events
      FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_audit_insert()
    """)
  end
end
