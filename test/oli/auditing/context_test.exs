defmodule Oli.Auditing.ContextTest do
  use ExUnit.Case, async: true

  alias Oli.Accounts.{Author, User}
  alias Oli.Auditing.Context

  @user %User{id: 41, name: "Grace Hopper", email: "grace.hopper@example.edu"}
  @author %Author{id: 5, name: "Alan Admin", email: "alan.admin@example.edu"}

  test "builds a user context with a snapshot and a generated operation" do
    context = Context.for_actor(@user, source: :ui)

    assert %Context{actor_type: :user, user_id: 41, author_id: nil, source: :ui} = context

    assert context.actor_snapshot == %{
             "id" => 41,
             "name" => "Grace Hopper",
             "email" => "grace.hopper@example.edu"
           }

    assert {:ok, _} = Ecto.UUID.cast(context.operation_id)
    assert context.parent_operation_id == nil
  end

  test "omits missing identity fields so the snapshot stays valid" do
    context = Context.for_actor(%User{id: 90, name: nil, email: nil}, source: :ui)

    assert context.actor_snapshot == %{"id" => 90}
    assert :ok = Oli.Auditing.Snapshot.validate(context.actor_snapshot)
  end

  test "builds an author context with explicit operation identifiers" do
    operation_id = Ecto.UUID.generate()
    parent = Ecto.UUID.generate()

    context =
      Context.for_actor(@author,
        source: :job,
        operation_id: operation_id,
        parent_operation_id: parent
      )

    assert %Context{actor_type: :author, author_id: 5, user_id: nil} = context
    assert context.operation_id == operation_id
    assert context.parent_operation_id == parent
  end

  test "requires a valid source for accounts" do
    assert_raise ArgumentError, fn -> Context.for_actor(@user, []) end
    assert_raise ArgumentError, fn -> Context.for_actor(@user, source: :system) end
    assert_raise ArgumentError, fn -> Context.for_actor(@user, source: :email) end
  end

  test "does not accept a version, sink, or skip option" do
    for option <- [schema_version: 1, sink: :none, skip: true] do
      assert_raise ArgumentError, fn -> Context.for_actor(@user, [{:source, :ui}, option]) end
    end
  end

  test "rejects operation identifiers that are not UUIDs" do
    assert_raise ArgumentError, fn ->
      Context.for_actor(@user, source: :ui, operation_id: "abc")
    end
  end

  test "builds system contexts only for catalog keys" do
    context = Context.for_system(:provider_provisioning)

    assert %Context{actor_type: :system, system_key: :provider_provisioning, source: :system} =
             context

    assert context.actor_snapshot == %{
             "key" => "provider_provisioning",
             "label" => "Identity provider provisioning"
           }

    assert Context.for_system(:scheduled_maintenance, source: :job).source == :job
    assert_raise FunctionClauseError, fn -> Context.for_system(:root) end
  end

  test "rejects actors that are not persisted accounts" do
    assert_raise FunctionClauseError, fn -> Context.for_actor(%User{id: nil}, source: :ui) end
  end
end
