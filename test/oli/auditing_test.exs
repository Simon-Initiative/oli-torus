defmodule Oli.AuditingTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Auditing
  alias Oli.Auditing.{Context, Error, EventExamples, LogEvent}
  alias Oli.Authoring.Course.Project

  describe "capture/4" do
    test "records a user actor" do
      admin = insert(:user)
      section = insert(:section)

      assert {:ok, %LogEvent{} = event} =
               Auditing.capture(admin, :section_created, section, %{})

      assert event.user_id == admin.id
      assert event.author_id == nil
      assert event.actor_snapshot["email"] == admin.email
    end

    test "records a project resource in the project column" do
      author = insert(:author)
      project = insert(:project, authors: [author])

      assert {:ok, %LogEvent{} = event} =
               Auditing.capture(author, :project_published, project, %{
                 "version" => "1.0.0",
                 "description" => "Initial release"
               })

      assert event.author_id == author.id
      assert event.project_id == project.id
      assert event.entity_type == :project
      assert event.event_type == :project_published
      assert event.details["version"] == "1.0.0"
    end

    test "records a section resource in the section column" do
      user = insert(:user)
      section = insert(:section)

      assert {:ok, %LogEvent{} = event} =
               Auditing.capture(user, :section_created, section, %{
                 "section_title" => section.title
               })

      assert event.user_id == user.id
      assert event.section_id == section.id
      assert event.event_type == :section_created
      assert event.details["section_title"] == section.title
    end

    test "drops detail keys outside the event contract" do
      admin = insert(:author)
      project = insert(:project)

      assert {:ok, event} =
               Auditing.log_admin_action(admin, :project_published, project, %{
                 "version" => "1.0",
                 "setting" => "maintenance_mode"
               })

      assert event.details == %{"version" => "1.0"}
    end

    test "rejects event types outside the legacy producers" do
      user = insert(:user)

      assert {:error, %Error{code: :invalid_event}} =
               Auditing.capture(user, :invalid_event_type, nil, %{})
    end

    test "rejects a nil actor without inventing a system actor" do
      user = insert(:user)

      assert {:error, %Error{code: :invalid_event, event_type: :user_deleted}} =
               Auditing.capture(nil, :user_deleted, user, %{})
    end
  end

  describe "build/2 and insert/1" do
    test "writes an event that satisfies its contract" do
      author = insert(:author)
      project = insert(:project)
      context = Context.for_actor(author, source: :ui)

      assert {:ok, changeset} =
               Auditing.build(context, %{
                 event_type: :project_published,
                 entity: {:project, project.id, project},
                 scope: %{project_id: project.id},
                 refs: [%{role: :resulting, type: :publication, id: 7, label: "1.0.0"}],
                 details: %{project_title: project.title},
                 event_key: "project:#{project.id}:published"
               })

      assert {:ok, event} = Auditing.insert(changeset)
      assert event.operation_id == context.operation_id
      assert event.details == %{"project_title" => project.title}
      assert event.search_text =~ "1.0.0"
      assert Auditing.get_event!(event.id, event.inserted_at).id == event.id
    end

    test "reports a skip event without changes as no changes" do
      admin = insert(:author)
      author = insert(:author)

      assert {:error, :no_changes} =
               Auditing.build(Context.for_actor(admin, source: :ui), %{
                 event_type: :author_role_changed,
                 entity: {:author, author.id, author},
                 affected: {:author, author.id},
                 event_key: "account:primary:author_role_changed"
               })
    end

    test "returns a changeset when the row breaks its contract" do
      author = insert(:author)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Auditing.build(Context.for_actor(author, source: :ui), %{
                 event_type: :project_published,
                 entity: {:project, 1, %{}},
                 event_key: "project:1:published"
               })

      assert errors_on(changeset)[:project_id]
    end

    test "append/3 writes inside a Multi and skips no-op events" do
      author = insert(:author)
      project = insert(:project)
      context = Context.for_actor(author, source: :ui)

      assert {:ok, %{published: %LogEvent{}, skipped: nil}} =
               Ecto.Multi.new()
               |> Auditing.append(:published, fn _changes ->
                 Auditing.build(context, %{
                   event_type: :project_published,
                   entity: {:project, project.id, project},
                   scope: %{project_id: project.id},
                   event_key: "project:#{project.id}:published"
                 })
               end)
               |> Auditing.append(:skipped, fn _changes -> :skip end)
               |> Repo.transaction()
    end

    test "append/3 rolls back earlier steps when the event cannot be written" do
      author = insert(:author)
      context = Context.for_actor(author, source: :ui)

      outside_every_partition =
        LogEvent.v2_changeset(%LogEvent{}, %{
          EventExamples.example(:project_published)
          | inserted_at: ~U[1990-01-01 00:00:00.000000Z]
        })

      for {builder, code} <- [
            {fn %{project: project} ->
               Auditing.build(context, %{
                 event_type: :project_published,
                 entity: {:project, project.id, project},
                 event_key: "project:#{project.id}:published"
               })
             end, :invalid_event},
            {fn _changes -> {:ok, outside_every_partition} end, :partition_missing},
            {fn _changes -> {:ok, nil} end, :invalid_event}
          ] do
        assert {:error, :event, %Error{code: ^code}, _changes} =
                 Ecto.Multi.new()
                 |> Ecto.Multi.insert(:project, build(:project, title: "Rolled back"))
                 |> Auditing.append(:event, builder)
                 |> Repo.transaction()

        refute Repo.get_by(Project, title: "Rolled back")
      end
    end

    test "build/2 takes only scope columns from the scope" do
      author = insert(:author)
      project = insert(:project)

      assert {:ok, changeset} =
               Auditing.build(Context.for_actor(author, source: :ui), %{
                 event_type: :project_published,
                 entity: {:project, project.id, project},
                 scope: %{project_id: project.id, author_id: 999, actor_type: :system},
                 event_key: "project:#{project.id}:published"
               })

      assert {:ok, event} = Auditing.insert(changeset)
      assert {event.actor_type, event.author_id} == {:author, author.id}
    end

    test "inspecting an event or its changeset does not show identities or values" do
      author = insert(:author, email: "redacted-author@example.edu")
      project = insert(:project)

      assert {:ok, changeset} =
               Auditing.build(Context.for_actor(author, source: :ui), %{
                 event_type: :project_published,
                 entity: {:project, project.id, project},
                 scope: %{project_id: project.id},
                 details: %{project_title: "Secret Title"},
                 event_key: "project:#{project.id}:published"
               })

      assert {:ok, event} = Auditing.insert(changeset)

      for value <- [changeset, event], text = inspect(value) do
        refute text =~ "redacted-author@example.edu"
        refute text =~ "Secret Title"
      end
    end
  end

  describe "list_events/1" do
    setup do
      admin = insert(:author)
      user = insert(:user)
      author = insert(:author)
      project = insert(:project, authors: [author])
      section = insert(:section)

      {:ok, event1} = user_deleted_event(admin, insert(:user))
      {:ok, event2} = Auditing.capture(author, :project_published, project, %{})
      {:ok, event3} = Auditing.capture(user, :section_created, section, %{})

      %{
        user: user,
        author: author,
        project: project,
        section: section,
        events: [event1, event2, event3]
      }
    end

    test "lists all events", %{events: events} do
      result_ids = Enum.map(Auditing.list_events(), & &1.id)

      Enum.each(events, fn event ->
        assert event.id in result_ids
      end)
    end

    test "filters by user_id", %{user: user} do
      results = Auditing.list_events(user_id: user.id)

      assert length(results) == 1
      assert Enum.all?(results, fn e -> e.user_id == user.id end)
    end

    test "filters by author_id", %{author: author} do
      results = Auditing.list_events(author_id: author.id)

      assert length(results) == 1
      assert Enum.all?(results, fn e -> e.author_id == author.id end)
    end

    test "filters by event_type" do
      results = Auditing.list_events(event_type: :project_published)

      assert length(results) >= 1
      assert Enum.all?(results, fn e -> e.event_type == :project_published end)
    end

    test "respects limit option" do
      admin = insert(:author)

      for _ <- 1..10 do
        user_deleted_event(admin, insert(:user))
      end

      assert length(Auditing.list_events(limit: 5)) == 5
    end

    test "orders by inserted_at desc by default", %{events: [_event1, _, event3]} do
      event_ids = Enum.map(Auditing.list_events(), & &1.id)
      event3_index = Enum.find_index(event_ids, fn id -> id == event3.id end)

      assert event3_index != nil
      assert event3_index < 3
    end

    test "preloads actor associations", %{user: user, author: author} do
      results = Auditing.list_events()

      user_event = Enum.find(results, fn e -> e.user_id == user.id end)
      assert user_event.actor.id == user.id
      assert user_event.actor.email == user.email

      author_event = Enum.find(results, fn e -> e.author_id == author.id end)
      assert author_event.actor.id == author.id
      assert author_event.actor.email == author.email
    end

    test "preloads resource associations", %{project: project, section: section} do
      results = Auditing.list_events()

      project_event = Enum.find(results, fn e -> e.project_id == project.id end)
      assert project_event.resource.id == project.id
      assert project_event.resource.title == project.title

      section_event = Enum.find(results, fn e -> e.section_id == section.id end)
      assert section_event.resource.id == section.id
      assert section_event.resource.title == section.title
    end
  end

  describe "get_event!/2" do
    test "returns the event with given id" do
      admin = insert(:user)
      {:ok, event} = user_deleted_event(admin, insert(:user))

      fetched_event = Auditing.get_event!(event.id, event.inserted_at)
      assert fetched_event.id == event.id
      assert fetched_event.user_id == admin.id
      assert fetched_event.event_type == :user_deleted
    end

    test "raises if event does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Auditing.get_event!(999_999, DateTime.utc_now())
      end
    end

    test "preloads associations" do
      admin = insert(:user)
      {:ok, event} = user_deleted_event(admin, insert(:user))

      fetched_event = Auditing.get_event!(event.id, event.inserted_at)
      assert fetched_event.actor.id == admin.id
      assert fetched_event.actor.email == admin.email
    end
  end

  describe "LogEvent.actor_name/1" do
    test "returns user name when available" do
      event = captured_by(insert(:user, name: "John Doe"))
      assert LogEvent.actor_name(event) == "John Doe"
    end

    test "returns user email when name is nil" do
      event = captured_by(insert(:user, name: nil, email: "user@example.com"))
      assert LogEvent.actor_name(event) == "user@example.com"
    end

    test "returns author name when available" do
      event = captured_by(insert(:author, name: "Jane Author"))
      assert LogEvent.actor_name(event) == "Jane Author"
    end

    test "returns author email when name is nil" do
      event = captured_by(insert(:author, name: nil, email: "author@example.com"))
      assert LogEvent.actor_name(event) == "author@example.com"
    end

    test "uses the stored snapshot when the account is not loaded" do
      user = insert(:user, name: "Stored Name")
      {:ok, event} = user_deleted_event(user, insert(:user))

      event = Repo.get_by!(LogEvent, id: event.id)
      assert event.actor == nil
      assert LogEvent.actor_name(event) == "Stored Name"
    end

    test "returns the account ID when nothing else is known" do
      assert LogEvent.actor_name(%LogEvent{user_id: 7, actor_snapshot: %{}}) == "User #7"
      assert LogEvent.actor_name(%LogEvent{author_id: 8, actor_snapshot: %{}}) == "Author #8"
    end

    test "returns Unknown for migrated rows without an actor and the label for system actors" do
      assert LogEvent.actor_name(%LogEvent{actor_type: :unknown, actor_snapshot: %{}}) ==
               "Unknown"

      assert LogEvent.actor_name(%LogEvent{
               actor_type: :system,
               actor_key: "provider_provisioning",
               actor_snapshot: %{"label" => "Identity provider provisioning"}
             }) == "Identity provider provisioning"
    end
  end

  describe "LogEvent.event_description/1" do
    test "returns description for user_deleted" do
      event = %LogEvent{event_type: :user_deleted, details: %{}}
      assert LogEvent.event_description(event) == "Deleted user account"
    end

    test "returns description for project_published with title" do
      event = %LogEvent{
        event_type: :project_published,
        details: %{"project_title" => "My Project"}
      }

      assert LogEvent.event_description(event) == "Published project My Project"
    end

    test "returns description for section_created with title" do
      event = %LogEvent{
        event_type: :section_created,
        details: %{"section_title" => "My Section"}
      }

      assert LogEvent.event_description(event) == "Created section My Section"
    end

    test "returns the catalog label for events without a custom description" do
      event = %LogEvent{event_type: :student_exception_updated, details: %{}}

      assert LogEvent.event_description(event) ==
               Oli.Auditing.EventCatalog.label(:student_exception_updated)
    end
  end

  defp captured_by(actor) do
    {:ok, event} = user_deleted_event(actor, insert(:user))
    Auditing.get_event!(event.id, event.inserted_at)
  end

  # User deletions are recorded by `Oli.Accounts.Audited`; this builds the same event row.
  defp user_deleted_event(actor, deleted) do
    {:ok, changeset} =
      Auditing.build(Context.for_actor(actor, source: :ui), %{
        event_type: :user_deleted,
        entity: {:user, deleted.id, deleted},
        affected: {:user, deleted.id},
        event_key: "account:primary:deleted",
        details: %{"email" => deleted.email, "name" => deleted.name}
      })

    Auditing.insert(changeset)
  end
end
