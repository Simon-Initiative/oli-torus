defmodule Oli.AuditingTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Auditing
  alias Oli.Auditing.LogEvent

  describe "capture/4" do
    test "captures user action" do
      user = insert(:user)

      assert {:ok, %LogEvent{} = event} =
               Auditing.capture(user, :user_created, nil, %{"email" => user.email})

      assert event.user_id == user.id
      assert event.author_id == nil
      assert event.event_type == :user_created
      assert event.details["email"] == user.email
    end

    test "captures author action" do
      author = insert(:author)

      assert {:ok, %LogEvent{} = event} =
               Auditing.capture(author, :author_created, nil, %{"email" => author.email})

      assert event.author_id == author.id
      assert event.user_id == nil
      assert event.event_type == :author_created
      assert event.details["email"] == author.email
    end

    test "captures action with project resource" do
      author = insert(:author)
      project = insert(:project, authors: [author])

      assert {:ok, %LogEvent{} = event} =
               Auditing.capture(author, :project_published, project, %{
                 "version" => "1.0.0",
                 "description" => "Initial release"
               })

      assert event.author_id == author.id
      assert event.project_id == project.id
      assert event.event_type == :project_published
      assert event.details["version"] == "1.0.0"
    end

    test "captures action with section resource" do
      user = insert(:user)
      section = insert(:section)

      assert {:ok, %LogEvent{} = event} =
               Auditing.capture(user, :section_created, section, %{
                 "title" => section.title
               })

      assert event.user_id == user.id
      assert event.section_id == section.id
      assert event.event_type == :section_created
      assert event.details["title"] == section.title
    end

    test "captures system action without actor" do
      assert {:ok, %LogEvent{} = event} =
               Auditing.capture(nil, :system_setting_changed, nil, %{
                 "setting" => "maintenance_mode",
                 "value" => true
               })

      assert event.user_id == nil
      assert event.author_id == nil
      assert event.event_type == :system_setting_changed
      assert event.details["setting"] == "maintenance_mode"
    end

    test "fails with invalid event type" do
      user = insert(:user)

      assert {:error, changeset} =
               Auditing.capture(user, :invalid_event_type, nil, %{})

      assert errors_on(changeset)[:event_type]
    end

    test "fails without actor" do
      assert {:error, changeset} =
               Auditing.capture(nil, :user_created, nil, %{})

      assert errors_on(changeset)[:base]
    end
  end

  describe "list_events/1" do
    setup do
      user = insert(:user)
      author = insert(:author)
      project = insert(:project, authors: [author])
      section = insert(:section)

      {:ok, event1} = Auditing.capture(user, :user_created, nil, %{"event" => "1"})
      {:ok, event2} = Auditing.capture(author, :project_published, project, %{"event" => "2"})
      {:ok, event3} = Auditing.capture(user, :section_created, section, %{"event" => "3"})

      %{
        user: user,
        author: author,
        project: project,
        section: section,
        events: [event1, event2, event3]
      }
    end

    test "lists all events", %{events: events} do
      results = Auditing.list_events()

      assert length(results) >= 3
      event_ids = Enum.map(events, & &1.id)
      result_ids = Enum.map(results, & &1.id)

      Enum.each(event_ids, fn id ->
        assert id in result_ids
      end)
    end

    test "filters by user_id", %{user: user} do
      results = Auditing.list_events(user_id: user.id)

      assert length(results) == 2
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

    test "filters by project_id", %{project: project} do
      results = Auditing.list_events(project_id: project.id)

      assert length(results) == 1
      assert Enum.all?(results, fn e -> e.project_id == project.id end)
    end

    test "filters by section_id", %{section: section} do
      results = Auditing.list_events(section_id: section.id)

      assert length(results) == 1
      assert Enum.all?(results, fn e -> e.section_id == section.id end)
    end

    test "respects limit option" do
      # Create more events
      for _ <- 1..10 do
        user = insert(:user)
        Auditing.capture(user, :user_created, nil, %{})
      end

      results = Auditing.list_events(limit: 5)
      assert length(results) == 5
    end

    test "orders by inserted_at desc by default", %{events: [_event1, _, event3]} do
      results = Auditing.list_events()

      # Most recent should be first (event3 was created last)
      # Since there might be other events in the database, we check that event3
      # appears before event1 in the results
      event_ids = Enum.map(results, & &1.id)
      event3_index = Enum.find_index(event_ids, fn id -> id == event3.id end)

      assert event3_index != nil
      # Should be in the first few results
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

  describe "get_event!/1" do
    test "returns the event with given id" do
      user = insert(:user)
      {:ok, event} = Auditing.capture(user, :user_created, nil, %{})

      fetched_event = Auditing.get_event!(event.id)
      assert fetched_event.id == event.id
      assert fetched_event.user_id == user.id
      assert fetched_event.event_type == :user_created
    end

    test "raises if event does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Auditing.get_event!(999_999)
      end
    end

    test "preloads associations" do
      user = insert(:user)
      {:ok, event} = Auditing.capture(user, :user_created, nil, %{})

      fetched_event = Auditing.get_event!(event.id)
      assert fetched_event.actor.id == user.id
      assert fetched_event.actor.email == user.email
    end
  end

  describe "convenience functions" do
    test "log_user_action/3" do
      user = insert(:user)

      assert {:ok, event} = Auditing.log_user_action(user, :user_created, %{"test" => true})
      assert event.user_id == user.id
      assert event.details["test"] == true
    end

    test "log_author_action/3" do
      author = insert(:author)

      assert {:ok, event} = Auditing.log_author_action(author, :author_created, %{"test" => true})
      assert event.author_id == author.id
      assert event.details["test"] == true
    end

    test "log_admin_action/4" do
      admin = insert(:user)
      project = insert(:project)

      assert {:ok, event} =
               Auditing.log_admin_action(
                 admin,
                 :project_published,
                 project,
                 %{"version" => "1.0"}
               )

      assert event.user_id == admin.id
      assert event.project_id == project.id
      assert event.details["admin_action"] == true
      assert event.details["version"] == "1.0"
    end
  end

  describe "LogEvent.actor_name/1" do
    test "returns user name when available" do
      user = insert(:user, name: "John Doe")
      {:ok, event} = Auditing.capture(user, :user_created, nil, %{})
      event = Auditing.get_event!(event.id)

      assert LogEvent.actor_name(event) == "John Doe"
    end

    test "returns user email when name is nil" do
      user = insert(:user, name: nil, email: "user@example.com")
      {:ok, event} = Auditing.capture(user, :user_created, nil, %{})
      event = Auditing.get_event!(event.id)

      assert LogEvent.actor_name(event) == "user@example.com"
    end

    test "returns author name when available" do
      author = insert(:author, name: "Jane Author")
      {:ok, event} = Auditing.capture(author, :author_created, nil, %{})
      event = Auditing.get_event!(event.id)

      assert LogEvent.actor_name(event) == "Jane Author"
    end

    test "returns author email when name is nil" do
      author = insert(:author, name: nil, email: "author@example.com")
      {:ok, event} = Auditing.capture(author, :author_created, nil, %{})
      event = Auditing.get_event!(event.id)

      assert LogEvent.actor_name(event) == "author@example.com"
    end

    test "returns User # when actor not loaded" do
      user = insert(:user)
      {:ok, event} = Auditing.capture(user, :user_created, nil, %{})

      # Don't preload associations
      event = Repo.get!(LogEvent, event.id)
      assert LogEvent.actor_name(event) == "User ##{user.id}"
    end

    test "returns System for nil actor" do
      {:ok, event} = Auditing.capture(nil, :system_setting_changed, nil, %{})

      assert LogEvent.actor_name(event) == "System"
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

    test "returns description for role_changed" do
      event = %LogEvent{
        event_type: :role_changed,
        details: %{"from_role" => "user", "to_role" => "admin"}
      }

      assert LogEvent.event_description(event) == "Changed role from user to admin"
    end

    test "returns event type for unknown events" do
      event = %LogEvent{event_type: :content_updated, details: %{}}
      assert LogEvent.event_description(event) == "Updated content"
    end
  end
end
