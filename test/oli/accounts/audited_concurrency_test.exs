defmodule Oli.Accounts.AuditedConcurrencyTest do
  # Concurrent transactions need independent connections and committed rows, so these tests run
  # outside the SQL sandbox and remove every row they create.
  use Oli.DataCase, async: false

  import Oli.Factory
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.Multi
  alias Oli.Accounts.{Audited, Author, SystemRole, User}
  alias Oli.Auditing.{Context, LogEvent}

  setup do
    fixtures =
      Sandbox.unboxed_run(Repo, fn ->
        admin = insert(:author, system_role_id: SystemRole.role_id().account_admin)
        other_admin = insert(:author, system_role_id: SystemRole.role_id().account_admin)
        user = insert(:user)

        %{admin: admin, other_admin: other_admin, user: user}
      end)

    on_exit(fn -> cleanup(fixtures) end)

    fixtures
  end

  test "concurrent deletions of the same user commit one deletion and one event", %{
    admin: admin,
    other_admin: other_admin,
    user: user
  } do
    parent = self()

    first =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          Multi.new()
          |> Audited.delete_user_multi(:deleted, Context.for_actor(admin, source: :ui), user.id)
          |> Multi.run(:hold, fn _repo, _changes ->
            send(parent, :first_deleted)

            receive do
              :release -> {:ok, nil}
            end
          end)
          |> Repo.transaction()
        end)
      end)

    assert_receive :first_deleted, 5_000

    second =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          Audited.delete_user(Context.for_actor(other_admin, source: :ui), user.id)
        end)
      end)

    await_lock_waiter()
    send(first.pid, :release)

    assert {:ok, %{deleted: %{user_id: user_id}}} = Task.await(first)
    assert user_id == user.id
    assert {:error, :not_found} = Task.await(second)

    assert [%LogEvent{author_id: author_id}] = deletion_events(user.id)
    assert author_id == admin.id
  end

  # Waits until another session is blocked on a row lock held by this test's first task.
  defp await_lock_waiter(attempts \\ 500) do
    %{rows: [[waiting]]} =
      Sandbox.unboxed_run(Repo, fn ->
        Repo.query!("""
        SELECT count(*) FROM pg_stat_activity
        WHERE datname = current_database() AND wait_event_type = 'Lock'
        """)
      end)

    case {waiting, attempts} do
      {0, 0} ->
        flunk("no session started waiting for the lock")

      {0, attempts} ->
        Process.sleep(10)
        await_lock_waiter(attempts - 1)

      _ ->
        :ok
    end
  end

  defp deletion_events(user_id) do
    Sandbox.unboxed_run(Repo, fn ->
      Repo.all(
        from(e in LogEvent,
          where: e.event_type == :user_deleted and e.affected_user_id == ^user_id
        )
      )
    end)
  end

  defp cleanup(%{admin: admin, other_admin: other_admin, user: user}) do
    author_ids = [admin.id, other_admin.id, user.author_id]

    Sandbox.unboxed_run(Repo, fn ->
      Repo.transaction(fn ->
        Repo.query!("SET LOCAL oli.audit_log_allow_mutation = 'on'")
        Repo.delete_all(from(e in LogEvent, where: e.affected_user_id == ^user.id))
      end)

      Repo.delete_all(from(u in User, where: u.id == ^user.id))
      Repo.delete_all(from(a in Author, where: a.id in ^author_ids))
    end)
  end
end
