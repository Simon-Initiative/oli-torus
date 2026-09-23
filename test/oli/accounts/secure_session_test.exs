defmodule Oli.Accounts.SecureSessionTest do
  use Oli.DataCase, async: true
  import Oli.Factory
  alias Oli.Accounts
  alias Oli.Accounts.UserToken
  alias Oli.Delivery.SecureAssessments.Scope

  test "ordinary and multiple secure tokens remain independent" do
    user = insert(:user)
    section = insert(:section)
    resource = insert(:resource)
    scope = %Scope{section_id: section.id, resource_id: resource.id}
    ordinary = Accounts.generate_user_session_token(user)
    secure = Accounts.generate_user_session_token(user, scope: scope)
    second_scope = %Scope{section_id: insert(:section).id, resource_id: insert(:resource).id}
    second = Accounts.generate_user_session_token(user, scope: second_scope)
    assert {:ok, %{scope: nil, user: %{id: id}}} = Accounts.get_user_session(ordinary)
    assert id == user.id
    assert {:ok, %{scope: ^scope, token_id: first_id}} = Accounts.get_user_session(secure)
    assert {:ok, %{scope: ^second_scope, token_id: second_id}} = Accounts.get_user_session(second)
    refute first_id == second_id
    assert Accounts.get_user_by_session_token(ordinary).id == user.id
    Accounts.delete_user_session_token(secure)
    assert {:error, :unauthenticated} = Accounts.get_user_session(secure)
    assert {:ok, %{scope: nil}} = Accounts.get_user_session(ordinary)
    assert {:ok, %{scope: ^second_scope}} = Accounts.get_user_session(second)
  end

  test "expiry and invalid scope fail without revoking another token" do
    user = insert(:user)
    ordinary = Accounts.generate_user_session_token(user)

    token =
      Accounts.generate_user_session_token(user,
        scope: %Scope{section_id: insert(:section).id, resource_id: insert(:resource).id}
      )

    Repo.update_all(from(t in UserToken, where: t.token == ^token),
      set: [inserted_at: DateTime.add(DateTime.utc_now(), -61, :day)]
    )

    assert {:error, :unauthenticated} = Accounts.get_user_session(token)
    assert {:error, :unauthenticated} = Accounts.get_user_session(nil)

    assert_raise FunctionClauseError, fn ->
      Accounts.generate_user_session_token(user, scope: %Scope{section_id: 1, resource_id: nil})
    end

    assert {:ok, %{scope: nil}} = Accounts.get_user_session(ordinary)
  end

  test "deleting a scoped resource revokes only its scoped tokens" do
    user = insert(:user)
    section = insert(:section)
    resource = insert(:resource)
    ordinary = Accounts.generate_user_session_token(user)

    secure =
      Accounts.generate_user_session_token(user,
        scope: %Scope{section_id: section.id, resource_id: resource.id}
      )

    Repo.delete!(resource)
    assert {:error, :unauthenticated} = Accounts.get_user_session(secure)
    assert {:ok, %{scope: nil}} = Accounts.get_user_session(ordinary)
  end

  test "database rejects partial scope and non-session scope" do
    user = insert(:user)
    section = insert(:section)
    resource = insert(:resource)

    for attrs <- [
          %{secure_section_id: section.id},
          %{secure_resource_id: resource.id},
          %{context: "confirm", secure_section_id: section.id, secure_resource_id: resource.id}
        ] do
      {_, record} = UserToken.build_session_token(user)

      changeset =
        record
        |> Ecto.Changeset.change(attrs)
        |> Ecto.Changeset.check_constraint(:secure_section_id, name: :secure_session_scope)

      assert {:error, _} = Repo.insert(changeset, mode: :savepoint)
    end
  end
end
