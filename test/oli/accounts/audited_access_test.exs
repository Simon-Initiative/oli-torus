defmodule Oli.Accounts.AuditedAccessTest do
  # The audit failure test adds a trigger to the audit table, which locks it until the test ends.
  use Oli.DataCase, async: false

  import ExUnit.CaptureLog
  import Oli.Factory

  alias Ecto.Multi
  alias Lti_1p3.Roles.PlatformRoles
  alias Oli.Accounts
  alias Oli.Accounts.{Audited, Author, SystemRole, User}
  alias Oli.Auditing.{Context, Error, LogEvent}

  setup do
    admin = insert(:author, system_role_id: SystemRole.role_id().system_admin)
    %{admin: admin, context: Context.for_actor(admin, source: :ui)}
  end

  describe "delete_author/2" do
    test "deletes the author and records author_deleted with its identity", %{
      admin: admin,
      context: context
    } do
      author = insert(:author)

      assert {:ok, %{author_id: author_id}} = Audited.delete_author(context, author.id)
      assert author_id == author.id
      refute Repo.get(Author, author.id)

      assert [event] = events(:author_deleted)
      assert event.author_id == admin.id
      assert event.entity_type == :author
      assert event.affected_author_id == author.id
      assert event.entity_snapshot["email"] == author.email
      assert event.event_key == "account:primary:deleted"

      assert event.details == %{
               "email" => author.email,
               "name" => author.name,
               "deleted_by" => admin.email
             }
    end

    test "a missing author returns :not_found and a user context is rejected", %{
      context: context
    } do
      author = insert(:author)
      user_context = Context.for_actor(insert(:user), source: :ui)

      assert {:error, :not_found} = Audited.delete_author(context, 999_999_999)
      assert {:error, :invalid_request} = Audited.delete_author(user_context, author.id)
      assert Repo.get(Author, author.id)
      assert events(:author_deleted) == []
    end

    test "composes into a caller's Multi and rolls back with it", %{context: context} do
      author = insert(:author)

      assert {:error, :later_step, :failed, _changes} =
               Multi.new()
               |> Audited.delete_author_multi(:deleted, context, author.id)
               |> Multi.run(:later_step, fn _repo, _changes -> {:error, :failed} end)
               |> Repo.transaction()

      assert Repo.get(Author, author.id)
      assert events(:author_deleted) == []
    end
  end

  describe "admin_update_user/3" do
    test "routes each changed field to its event within one operation", %{
      admin: admin,
      context: context
    } do
      user = insert(:user, can_create_sections: false, is_internal: false)

      assert {:ok, %User{} = updated} =
               Audited.admin_update_user(context, user.id, %{
                 "given_name" => "Renamed",
                 "can_create_sections" => "true",
                 "is_internal" => "true"
               })

      assert updated.given_name == "Renamed"
      assert updated.can_create_sections
      assert updated.is_internal

      [updated_event] = events(:account_updated)
      [rights_event] = events(:account_creation_rights_changed)
      [internal_event] = events(:account_internal_flag_changed)

      for event <- [updated_event, rights_event, internal_event] do
        assert event.author_id == admin.id
        assert event.affected_user_id == user.id
        assert event.operation_id == context.operation_id
      end

      assert updated_event.changes["given_name"] == %{
               "operation" => "set",
               "before" => user.given_name,
               "after" => "Renamed"
             }

      refute Map.has_key?(updated_event.changes, "can_create_sections")

      assert rights_event.changes == %{
               "can_create_sections" => %{
                 "operation" => "set",
                 "before" => false,
                 "after" => true
               }
             }

      assert internal_event.changes == %{
               "is_internal" => %{"operation" => "set", "before" => false, "after" => true}
             }

      assert internal_event.details == %{
               "account_type" => "user",
               "user_id" => user.id,
               "previous" => false,
               "is_internal" => true
             }
    end

    test "an unchanged submission writes no event", %{context: context} do
      user = insert(:user)

      assert {:ok, _} =
               Audited.admin_update_user(context, user.id, %{"given_name" => user.given_name})

      assert all_events(user) == []
    end

    test "a protected field is rejected without writing", %{context: context} do
      user = insert(:user, independent_learner: false)

      assert {:error, :protected} =
               Audited.admin_update_user(context, user.id, %{
                 "given_name" => "Renamed",
                 "independent_learner" => "true"
               })

      reloaded = Repo.get!(User, user.id)
      assert reloaded.given_name == user.given_name
      refute reloaded.independent_learner
      assert all_events(user) == []
    end

    test "validation errors return the changeset", %{context: context} do
      user = insert(:user)

      assert {:error, %Ecto.Changeset{valid?: false}} =
               Audited.admin_update_user(context, user.id, %{"given_name" => ""})

      assert all_events(user) == []
    end

    test "a failing audit insert rolls back the update", %{context: context} do
      user = insert(:user, is_internal: false)
      reject_audit_inserts()

      log =
        capture_log(fn ->
          assert {:error, %Error{code: :insert_failed}} =
                   Audited.admin_update_user(context, user.id, %{"is_internal" => "true"})
        end)

      assert log =~ "Audit event write failed code=insert_failed"
      refute Repo.get!(User, user.id).is_internal
    end

    test "refuses to run inside another transaction", %{context: context} do
      user = insert(:user)

      assert {:ok, {:error, :nested_transaction}} =
               Repo.transaction(fn ->
                 Audited.admin_update_user(context, user.id, %{"given_name" => "Renamed"})
               end)
    end
  end

  describe "admin_update_author/3" do
    test "records author_role_changed with the persisted previous role", %{
      admin: admin,
      context: context
    } do
      author = insert(:author)
      account_admin = SystemRole.role_id().account_admin

      assert {:ok, %Author{system_role_id: ^account_admin}} =
               Audited.admin_update_author(context, author.id, %{
                 "system_role_id" => account_admin
               })

      assert [event] = events(:author_role_changed)
      assert event.affected_author_id == author.id
      assert event.event_key == "account:primary:author_role_changed"

      assert event.changes == %{
               "system_role_id" => %{
                 "operation" => "set",
                 "before" => SystemRole.role_id().author,
                 "after" => account_admin
               }
             }

      assert event.details["actor_email"] == admin.email
      assert event.details["previous_role"] == "Author"
      assert event.details["new_role"] == "Account Admin"
    end

    test "an unknown role is a validation error", %{context: context} do
      author = insert(:author)

      assert {:error, %Ecto.Changeset{errors: errors}} =
               Audited.admin_update_author(context, author.id, %{"system_role_id" => 99})

      assert Keyword.has_key?(errors, :system_role_id)
      assert all_events(author) == []
    end

    test "a protected field is rejected without writing", %{context: context} do
      author = insert(:author)

      assert {:error, :protected} =
               Audited.admin_update_author(context, author.id, %{
                 "locked_at" => DateTime.utc_now()
               })

      refute Repo.get!(Author, author.id).locked_at
    end
  end

  describe "lock_account/3 and unlock_account/3" do
    test "lock and unlock record their events; repeating them records nothing", %{
      context: context
    } do
      user = insert(:user)

      assert {:ok, %User{locked_at: %DateTime{}}} = Audited.lock_account(context, :user, user.id)
      assert {:ok, %User{locked_at: %DateTime{}}} = Audited.lock_account(context, :user, user.id)
      assert [locked] = events(:account_locked)
      assert locked.event_key == "account:primary:locked"
      assert %{"locked_at" => %{"before" => nil, "after" => after_value}} = locked.changes
      assert is_binary(after_value)

      assert {:ok, %User{locked_at: nil}} = Audited.unlock_account(context, :user, user.id)
      assert {:ok, %User{locked_at: nil}} = Audited.unlock_account(context, :user, user.id)
      assert [unlocked] = events(:account_unlocked)
      assert %{"locked_at" => %{"after" => nil}} = unlocked.changes
    end

    test "locks authors too", %{context: context} do
      author = insert(:author)

      assert {:ok, %Author{locked_at: %DateTime{}}} =
               Audited.lock_account(context, :author, author.id)

      assert [event] = events(:account_locked)
      assert event.affected_author_id == author.id
    end

    test "a missing account returns :not_found", %{context: context} do
      assert {:error, :not_found} = Audited.lock_account(context, :user, 999_999_999)
    end
  end

  describe "admin_confirm_email/2" do
    test "records the confirmation as account_updated", %{context: context} do
      author = insert(:author, email_confirmed_at: nil)

      assert {:ok, %Author{email_confirmed_at: %DateTime{}}} =
               Audited.admin_confirm_email(context, {:author, author.id})

      assert [event] = events(:account_updated)
      assert %{"email_confirmed_at" => %{"before" => nil}} = event.changes
    end
  end

  describe "sync_platform_roles/3" do
    test "records the previous and resulting role URIs under the given actor" do
      user = insert(:user)
      context = Context.for_system(:provider_provisioning)
      instructor = PlatformRoles.get_role(:institution_instructor)

      assert {:ok, %User{}} = Audited.sync_platform_roles(context, user.id, [instructor])

      assert [event] = events(:account_permissions_changed)
      assert event.actor_type == :system
      assert event.actor_key == "provider_provisioning"
      assert event.affected_user_id == user.id

      assert event.changes == %{
               "platform_roles" => %{
                 "operation" => "set",
                 "before" => [],
                 "after" => [instructor.uri]
               }
             }

      assert Accounts.get_user!(user.id, preload: [:platform_roles]).platform_roles
             |> Enum.map(& &1.uri) == [instructor.uri]
    end

    test "the same set of roles writes nothing" do
      user = insert(:user)
      context = Context.for_system(:provider_provisioning)
      learner = PlatformRoles.get_role(:institution_learner)

      assert {:ok, _} = Audited.sync_platform_roles(context, user.id, [learner])
      assert {:ok, _} = Audited.sync_platform_roles(context, user.id, [learner])
      assert [_only_one] = events(:account_permissions_changed)
    end

    test "composes into a caller's function transaction" do
      user = insert(:user)
      context = Context.for_actor(user, source: :ui)
      learner = PlatformRoles.get_role(:institution_learner)

      assert {:ok, {:ok, %{roles: %User{}}}} =
               Repo.transaction(fn ->
                 Multi.new()
                 |> Audited.sync_platform_roles_multi(:roles, context, {user.id, [learner]})
                 |> Repo.transaction()
               end)

      assert [event] = events(:account_permissions_changed)
      assert event.user_id == user.id
    end
  end

  describe "update_own_profile/3" do
    test "updates the account's own names and records account_updated" do
      author = insert(:author)
      context = Context.for_actor(author, source: :ui)

      assert {:ok, %Author{given_name: "New"}} =
               Audited.update_own_profile(context, author, %{
                 "name" => author.name,
                 "given_name" => "New",
                 "family_name" => author.family_name
               })

      assert [event] = events(:account_updated)
      assert event.author_id == author.id
      assert event.affected_author_id == author.id
      assert %{"given_name" => %{"after" => "New"}} = event.changes
    end

    test "protected fields change nothing" do
      author = insert(:author)
      context = Context.for_actor(author, source: :ui)

      for attrs <- [
            %{"system_role_id" => SystemRole.role_id().system_admin},
            %{"locked_at" => DateTime.utc_now()},
            %{"email" => "other@example.com"},
            %{"is_internal" => "true"}
          ] do
        assert {:error, :protected} =
                 Audited.update_own_profile(context, author, Map.put(attrs, "given_name", "New"))
      end

      assert Repo.get!(Author, author.id) |> Map.take([:given_name, :system_role_id, :email]) ==
               Map.take(author, [:given_name, :system_role_id, :email])

      assert all_events(author) == []
    end

    test "only the account itself can update its profile", %{context: context} do
      user = insert(:user)

      assert {:error, :invalid_request} =
               Audited.update_own_profile(context, user, %{"given_name" => "New"})
    end
  end

  defp events(event_type),
    do: Repo.all(from(e in LogEvent, where: e.event_type == ^event_type, order_by: e.id))

  defp all_events(%Oli.Accounts.User{id: id}),
    do: Repo.all(from(e in LogEvent, where: e.affected_user_id == ^id))

  defp all_events(%Oli.Accounts.Author{id: id}),
    do: Repo.all(from(e in LogEvent, where: e.affected_author_id == ^id))

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
