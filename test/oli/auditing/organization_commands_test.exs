defmodule Oli.Auditing.OrganizationCommandsTest do
  # The audit failure test adds a trigger to the audit table, which locks it until the test ends.
  use Oli.DataCase, async: false

  import ExUnit.CaptureLog
  import Oli.Factory

  alias Ecto.Multi
  alias Oli.Auditing.{Context, Error, LogEvent}
  alias Oli.Groups
  alias Oli.Institutions.{Institution, PendingRegistration}
  alias Oli.Inventories.Publisher

  setup do
    admin = insert(:author)
    %{admin: admin, context: Context.for_actor(admin, source: :ui)}
  end

  describe "institutions" do
    test "create and update record the institution settings with its scope", %{
      admin: admin,
      context: context
    } do
      {:ok, institution} =
        Oli.Institutions.Audited.create_institution(context, %{
          name: "Audited U",
          country_code: "US",
          institution_email: "admin@audited.edu",
          institution_url: "https://audited.edu"
        })

      {:ok, _} =
        Oli.Institutions.Audited.update_institution(context, institution.id, %{name: "Audited U2"})

      {:ok, _} =
        Oli.Institutions.Audited.update_institution(context, institution.id, %{name: "Audited U2"})

      assert [created, updated] = events(:institution_settings_changed)
      assert created.author_id == admin.id
      assert created.institution_id == institution.id
      assert created.changes["name"] == %{"operation" => "set", "after" => "Audited U"}

      assert updated.changes == %{
               "name" => %{"operation" => "set", "before" => "Audited U", "after" => "Audited U2"}
             }
    end

    test "a failing audit insert rolls back the change", %{context: context} do
      institution = insert(:institution, name: "Before")
      reject_audit_inserts()

      log =
        capture_log(fn ->
          assert {:error, %Error{code: :insert_failed}} =
                   Oli.Institutions.Audited.update_institution(context, institution.id, %{
                     name: "After"
                   })
        end)

      assert log =~ "Audit event write failed"
      assert Repo.get!(Institution, institution.id).name == "Before"
    end
  end

  describe "registration requests" do
    test "approval records the created institution, registration, and deployment", %{
      context: context
    } do
      pending = insert(:pending_registration, institution_url: "https://approved.example.edu")

      {:ok, {institution, registration, deployment}} =
        Oli.Institutions.Audited.approve_pending_registration(context, pending.id, :new)

      refute Repo.get(PendingRegistration, pending.id)
      assert [_institution_event] = events(:institution_settings_changed)
      lms = events(:lms_settings_changed)
      assert Enum.map(lms, & &1.entity_type) |> Enum.sort() == [:deployment, :registration]
      assert Enum.find(lms, &(&1.entity_type == :deployment)).institution_id == institution.id

      assert Enum.find(lms, &(&1.entity_type == :registration)).entity_id ==
               to_string(registration.id)

      assert deployment.institution_id == institution.id
    end

    test "decline records the request without its contact email", %{
      admin: admin,
      context: context
    } do
      pending =
        insert(:pending_registration,
          institution_email: "contact@declined.edu",
          institution_url: "https://declined.edu"
        )

      {:ok, _} = Oli.Institutions.Audited.decline_pending_registration(context, pending.id)

      assert {:error, :not_found} =
               Oli.Institutions.Audited.decline_pending_registration(context, pending.id)

      assert [event] = events(:lms_registration_declined)
      assert event.author_id == admin.id
      assert event.entity_type == :pending_registration
      assert event.details["institution_url"] == "https://declined.edu"
      assert event.details["issuer"] == pending.issuer
      refute inspect(event) =~ "contact@declined.edu"
    end
  end

  describe "communities" do
    test "members are recorded as added and removed on the community", %{context: context} do
      community = insert(:community)
      user = insert(:user)

      {:ok, _} =
        Groups.create_community_account(context, %{community_id: community.id, user_id: user.id})

      {:ok, _} =
        Groups.delete_community_account(context, %{community_id: community.id, user_id: user.id})

      assert [added, removed] = events(:community_settings_changed)
      assert added.entity_id == to_string(community.id)

      assert added.changes == %{
               "members" => %{
                 "operation" => "added",
                 "after" => [%{"user_id" => user.id, "is_admin" => false}]
               }
             }

      assert removed.changes["members"]["operation"] == "removed"
      assert added.operation_id == removed.operation_id
    end

    test "a bulk add keeps the valid targets and reports the invalid ones", %{context: context} do
      community = insert(:community)
      author = insert(:author)

      assert {:error, :author_not_found} =
               Groups.create_community_accounts_from_emails(
                 context,
                 "admin",
                 [author.email, "missing@example.edu"],
                 %{community_id: community.id, is_admin: true}
               )

      assert [added] = events(:community_settings_changed)

      assert added.changes["members"]["after"] == [
               %{"author_id" => author.id, "is_admin" => true}
             ]
    end

    test "Cognito provisioning composes the membership into its transaction" do
      community = insert(:community)
      user = insert(:user)
      context = Context.for_system(:provider_provisioning)

      assert {:error, :later, :failed, _} =
               Multi.new()
               |> Multi.run(:membership, fn _repo, _changes ->
                 Groups.find_or_create_community_user_account(context, user.id, community.id)
               end)
               |> Multi.run(:later, fn _repo, _changes -> {:error, :failed} end)
               |> Repo.transaction()

      assert events(:community_settings_changed) == []
    end
  end

  describe "publishers" do
    test "setting the default records the old and new default in one operation", %{
      context: context
    } do
      previous = Oli.Inventories.default_publisher()
      publisher = insert(:publisher)

      {:ok, %Publisher{default: true}} =
        Oli.Inventories.Audited.set_default_publisher(context, publisher.id)

      events = events(:publisher_settings_changed)

      assert Enum.map(events, & &1.entity_id) |> Enum.sort() ==
               Enum.sort([to_string(previous.id), to_string(publisher.id)])

      assert events |> Enum.map(& &1.operation_id) |> Enum.uniq() |> length() == 1
    end

    test "the default publisher cannot be deleted", %{context: context} do
      default = Oli.Inventories.default_publisher()

      assert {:error, %Ecto.Changeset{}} =
               Oli.Inventories.Audited.delete_publisher(context, default.id)

      assert events(:publisher_settings_changed) == []
    end
  end

  describe "research consent" do
    test "the system form setting is recorded", %{context: context} do
      {:ok, _} = Oli.Institutions.Audited.update_system_research_consent(context, :no_form)

      assert [event] = events(:research_consent_settings_changed)
      assert event.entity_type == :research_consent
      assert event.changes["research_consent"]["after"] == "no_form"
    end
  end

  describe "external tools" do
    test "custom parameters are recorded only as a redaction marker", %{context: context} do
      {:ok, {instance, _activity, deployment}} =
        Oli.Lti.Audited.register_external_tool(context, %{
          "name" => "Marker Tool",
          "description" => "desc",
          "target_link_uri" => "https://tool.example.edu/launch",
          "client_id" => "marker-client",
          "login_url" => "https://tool.example.edu/login",
          "keyset_url" => "https://tool.example.edu/keys",
          "redirect_uris" => "https://tool.example.edu/redirect",
          "custom_params" => "secret=MARKER-SECRET-123"
        })

      {:ok, _} =
        Oli.Lti.Audited.update_external_tool_deployment(context, deployment.deployment_id, %{
          status: :disabled
        })

      assert [created, disabled] = events(:external_tool_settings_changed)
      assert created.entity_id == to_string(instance.id)
      assert created.changes["custom_params"] == Oli.Auditing.Changes.secret_record()
      refute inspect(created) =~ "MARKER-SECRET-123"

      assert disabled.changes["status"] == %{
               "operation" => "set",
               "before" => "enabled",
               "after" => "disabled"
             }
    end
  end

  describe "section deep links" do
    test "an instructor's choice is recorded with the section scope; replacing it records the change" do
      section = insert(:section)
      resource = insert(:resource)
      instructor = insert(:user)
      context = Context.for_actor(instructor, source: :ui)

      persist = fn title ->
        Multi.new()
        |> Oli.Lti.Audited.persist_deep_link_multi(:deep_link, context, %{
          "section_id" => section.id,
          "resource_id" => resource.id,
          "type" => "ltiResourceLink",
          "url" => "https://tool.example.edu/item",
          "title" => title,
          "custom" => %{"token" => "MARKER-CUSTOM"}
        })
        |> Repo.transaction()
      end

      {:ok, _} = persist.("First")
      {:ok, _} = persist.("Second")

      assert [created, replaced] = events(:external_tool_settings_changed)
      assert created.user_id == instructor.id
      assert created.section_id == section.id
      assert created.resource_id == resource.id
      assert created.changes["custom"] == Oli.Auditing.Changes.secret_record()

      assert replaced.changes == %{
               "title" => %{"operation" => "set", "before" => "First", "after" => "Second"}
             }

      refute inspect(created) =~ "MARKER-CUSTOM"
    end
  end

  defp events(event_type),
    do: Repo.all(from(e in LogEvent, where: e.event_type == ^event_type, order_by: e.id))

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
