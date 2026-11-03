defmodule Oli.Accounts.AuditedTest do
  # The audit failure test adds a trigger to the audit table, which locks it until the test ends.
  use Oli.DataCase, async: false

  import ExUnit.CaptureLog
  import Oli.Factory

  alias Ecto.Multi
  alias Oli.Accounts.{Audited, SystemRole, User}
  alias Oli.Auditing.{Context, Error, LogEvent}

  setup do
    admin = insert(:author, system_role_id: SystemRole.role_id().account_admin)
    user = insert(:user)

    %{admin: admin, user: user, context: Context.for_actor(admin, source: :ui)}
  end

  describe "delete_user/2" do
    test "deletes the user and records one user_deleted event", %{
      admin: admin,
      user: user,
      context: context
    } do
      assert {:ok, %{user_id: user_id}} = Audited.delete_user(context, user.id)
      assert user_id == user.id
      refute Repo.get(User, user.id)

      assert [event] = deletion_events(user.id)
      assert event.actor_type == :author
      assert event.author_id == admin.id

      assert event.actor_snapshot == %{
               "id" => admin.id,
               "name" => admin.name,
               "email" => admin.email
             }

      assert event.entity_type == :user
      assert event.entity_id == to_string(user.id)

      assert event.entity_snapshot == %{
               "id" => user.id,
               "name" => user.name,
               "email" => user.email
             }

      assert event.event_key == "account:primary:deleted"
      assert event.outcome == :succeeded
      assert event.source == :ui
      assert event.operation_id == context.operation_id

      assert event.details == %{
               "email" => user.email,
               "name" => user.name,
               "deleted_by" => admin.email
             }
    end

    test "invalid requests are rejected without writing", %{user: user, context: context} do
      user_context = Context.for_actor(insert(:user), source: :ui)
      system_context = Context.for_system(:scheduled_maintenance)

      assert {:error, :invalid_request} = Audited.delete_user(user_context, user.id)
      assert {:error, :invalid_request} = Audited.delete_user(system_context, user.id)
      assert {:error, :invalid_request} = Audited.delete_user(context, 0)
      assert {:error, :invalid_request} = Audited.delete_user(context, "#{user.id}")
      assert {:error, :invalid_request} = Audited.delete_user(%{author_id: 1}, user.id)

      assert Repo.get(User, user.id)
      assert deletion_events(user.id) == []
    end

    test "a missing user returns :not_found without an event", %{context: context} do
      assert {:error, :not_found} = Audited.delete_user(context, 999_999_999)
      assert Repo.aggregate(where(LogEvent, event_type: :user_deleted), :count) == 0
    end

    test "deleting the same user again returns :not_found and records nothing more", %{
      user: user,
      context: context
    } do
      assert {:ok, _} = Audited.delete_user(context, user.id)
      assert {:error, :not_found} = Audited.delete_user(context, user.id)
      assert [_event] = deletion_events(user.id)
    end

    test "a row that still references the user blocks the deletion", %{
      user: user,
      context: context
    } do
      insert(:post, user: user)

      assert {:error, :delete_failed} = Audited.delete_user(context, user.id)
      assert Repo.get(User, user.id)
      assert deletion_events(user.id) == []
    end

    test "a failing audit insert rolls back the deletion", %{user: user, context: context} do
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

      log =
        capture_log(fn ->
          assert {:error, %Error{code: :insert_failed, event_type: :user_deleted}} =
                   Audited.delete_user(context, user.id)
        end)

      assert log =~ "Audit event write failed code=insert_failed event_type=user_deleted"
      refute log =~ user.email
      assert Repo.get(User, user.id)
    end

    test "refuses to run inside another transaction", %{user: user, context: context} do
      assert {:ok, {:error, :nested_transaction}} =
               Repo.transaction(fn -> Audited.delete_user(context, user.id) end)

      assert Repo.get(User, user.id)
    end
  end

  describe "delete_user_multi/4" do
    test "stores the result under the given name", %{user: user, context: context} do
      assert {:ok, %{deleted: %{user_id: user_id}}} =
               Multi.new()
               |> Audited.delete_user_multi(:deleted, context, user.id)
               |> Repo.transaction()

      assert user_id == user.id
      assert [_event] = deletion_events(user.id)
    end

    test "a later failing step rolls back the deletion and its event", %{
      user: user,
      context: context
    } do
      assert {:error, :later_step, :failed, _changes} =
               Multi.new()
               |> Audited.delete_user_multi(:deleted, context, user.id)
               |> Multi.run(:later_step, fn _repo, _changes -> {:error, :failed} end)
               |> Repo.transaction()

      assert Repo.get(User, user.id)
      assert deletion_events(user.id) == []
    end
  end

  defp deletion_events(user_id) do
    Repo.all(
      from(e in LogEvent, where: e.event_type == :user_deleted and e.affected_user_id == ^user_id)
    )
  end
end
