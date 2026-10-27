defmodule Oli.Delivery.SecureAssessmentAdmissionTest do
  use Oli.DataCase, async: false
  import Oli.Factory
  alias Oli.Accounts
  alias Oli.Accounts.UserToken
  alias Oli.Delivery.SecureAssessments, as: Policy
  alias Oli.Delivery.SecureAssessments.Admission

  setup do
    previous = Application.get_env(:oli, :supports_secure_delivery)
    Application.put_env(:oli, :supports_secure_delivery, true)
    on_exit(fn -> Application.put_env(:oli, :supports_secure_delivery, previous) end)
    user = insert(:user)
    section = insert(:section)
    resource = insert(:resource)

    sr =
      insert(:section_resource,
        section: section,
        resource_id: resource.id,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        graded: true,
        secure_delivery: true
      )

    insert(:enrollment, user: user, section: section)
    admission = %Admission{user_id: user.id, section_id: section.id, resource_id: resource.id}
    %{user: user, section: section, sr: sr, admission: admission}
  end

  test "provider-neutral admission issues an immutable, independently scoped token", c do
    ordinary = Accounts.generate_user_session_token(c.user)
    assert {:ok, first} = Policy.issue_session(c.user, c.admission)
    assert {:ok, second} = Policy.issue_session(c.user, c.admission)
    assert first != second

    assert {:ok, %{scope: %{section_id: section, resource_id: resource}}} =
             Accounts.get_user_session(first)

    assert section == c.section.id
    assert resource == c.sr.resource_id
    Accounts.delete_user_session_token(first)
    assert {:ok, %{scope: nil}} = Accounts.get_user_session(ordinary)
    assert {:ok, _} = Accounts.get_user_session(second)
  end

  test "current policy, grade, page type, capability and enrollment are rechecked", c do
    for attrs <- [
          %{secure_delivery: false},
          %{graded: false},
          %{resource_type_id: Oli.Resources.ResourceType.id_for_container()}
        ] do
      Repo.update!(Ecto.Changeset.change(c.sr, attrs))
      assert {:error, :secure_target_invalid} = Policy.issue_session(c.user, c.admission)
      Repo.update!(Ecto.Changeset.change(Repo.reload!(c.sr), Map.take(c.sr, Map.keys(attrs))))
    end

    Application.put_env(:oli, :supports_secure_delivery, false)
    assert {:error, :secure_delivery_unsupported} = Policy.issue_session(c.user, c.admission)
    Application.put_env(:oli, :supports_secure_delivery, true)

    Repo.update_all(
      from(e in Oli.Delivery.Sections.Enrollment, where: e.section_id == ^c.section.id),
      set: [status: :suspended]
    )

    assert {:error, :not_enrolled} = Policy.issue_session(c.user, c.admission)
    assert Repo.aggregate(UserToken, :count) == 0
  end

  test "mismatched identity, missing target and rolled-back persistence issue no token", c do
    assert {:error, :secure_target_invalid} = Policy.issue_session(insert(:user), c.admission)

    assert {:error, :secure_target_invalid} =
             Policy.issue_session(c.user, %{c.admission | resource_id: insert(:resource).id})

    assert {:error, :simulated_persistence_failure} =
             Repo.transaction(fn ->
               assert {:ok, _token} = Policy.issue_session(c.user, c.admission)
               Repo.rollback(:simulated_persistence_failure)
             end)

    assert Repo.aggregate(UserToken, :count) == 0
  end

  test "concurrent launches share the assessment lock while policy edits wait" do
    {user, section, revision, sr, enrollment} =
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        user = insert(:user)

        section =
          insert(:section,
            section_resource_migration_version:
              Oli.Delivery.Sections.SectionResourceMigration.current_version()
          )

        revision =
          insert(:revision,
            graded: true,
            resource_type_id: Oli.Resources.ResourceType.id_for_page()
          )

        sr =
          insert(:section_resource,
            section: section,
            resource_id: revision.resource_id,
            revision_slug: revision.slug,
            resource_type_id: revision.resource_type_id,
            graded: true,
            secure_delivery: true
          )

        enrollment = insert(:enrollment, user: user, section: section)
        {user, section, revision, sr, enrollment}
      end)

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        Repo.delete_all(from t in UserToken, where: t.user_id == ^user.id)
        Enum.each([enrollment, sr, section, revision], &Repo.delete!/1)
        Repo.delete!(Oli.Resources.Resource |> Repo.get!(revision.resource_id))
        Repo.delete!(user)
      end)
    end)

    claims = %{
      "https://purl.imsglobal.org/spec/lti/claim/custom" => %{
        "torus_resource_type" => "page",
        "torus_resource_id" => revision.slug
      }
    }

    admission = %Admission{
      user_id: user.id,
      section_id: section.id,
      resource_id: revision.resource_id
    }

    parent = self()

    first =
      Task.async(fn ->
        Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
          Repo.transaction(fn ->
            assert %{resource: %{id: id}} = OliWeb.LtiRedirect.resolve_target(claims, section)
            assert id == sr.id
            assert {:ok, token} = Policy.issue_session(user, admission)
            send(parent, :first_launch_admitted)

            receive do
              :commit -> token
            after
              5_000 -> raise "first launch timed out"
            end
          end)
        end)
      end)

    assert_receive :first_launch_admitted, 1_000

    second =
      Task.async(fn ->
        Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
          Repo.transaction(fn ->
            OliWeb.LtiRedirect.resolve_target(claims, section)
            assert {:ok, token} = Policy.issue_session(user, admission)
            token
          end)
        end)
      end)

    second_result = Task.yield(second, 1_000)

    editor =
      Task.async(fn ->
        Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
          send(parent, :policy_edit_started)
          Repo.update!(Ecto.Changeset.change(sr, secure_delivery: false))
        end)
      end)

    assert_receive :policy_edit_started, 1_000
    editor_result = Task.yield(editor, 100)

    # Release and collect all connections before asserting so failures clean up too.
    send(first.pid, :commit)
    assert {:ok, first_token} = Task.await(first)

    case second_result do
      nil -> Task.await(second)
      _ -> :ok
    end

    case editor_result do
      nil -> Task.await(editor)
      _ -> :ok
    end

    assert {:ok, {:ok, second_token}} = second_result
    assert first_token != second_token
    assert editor_result == nil

    assert {:error, :secure_target_invalid} =
             Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
               Policy.issue_session(user, admission)
             end)
  end

  test "concurrent policy edit wins before waiting admission can insert a token" do
    # Separate committed connections are required to exercise real PostgreSQL row locks.
    fixture =
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        user = insert(:user)
        section = insert(:section)
        resource = insert(:resource)

        sr =
          insert(:section_resource,
            section: section,
            resource_id: resource.id,
            resource_type_id: Oli.Resources.ResourceType.id_for_page(),
            graded: true,
            secure_delivery: true
          )

        enrollment = insert(:enrollment, user: user, section: section)
        {user, section, resource, sr, enrollment}
      end)

    {user, section, resource, sr, enrollment} = fixture

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        Repo.delete_all(from t in UserToken, where: t.user_id == ^user.id)
        Enum.each([enrollment, sr, section, resource, user], &Repo.delete!/1)
      end)
    end)

    parent = self()

    editor =
      Task.async(fn ->
        Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
          Repo.transaction(fn ->
            Repo.update!(Ecto.Changeset.change(sr, secure_delivery: false))
            send(parent, :policy_locked)

            receive do
              :commit -> :ok
            after
              5_000 -> raise "editor timed out"
            end
          end)
        end)
      end)

    assert_receive :policy_locked

    entrant =
      Task.async(fn ->
        Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
          send(parent, :admission_started)

          Policy.issue_session(user, %Admission{
            user_id: user.id,
            section_id: section.id,
            resource_id: resource.id
          })
        end)
      end)

    assert_receive :admission_started
    assert Task.yield(entrant, 100) == nil
    send(editor.pid, :commit)
    assert {:ok, :ok} = Task.await(editor)
    assert {:error, :secure_target_invalid} = Task.await(entrant)
  end
end
