defmodule Oli.Scenarios.DemoAccountsTest do
  use OliWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}
  alias Oli.Repo
  alias Oli.Scenarios
  alias Oli.Scenarios.{DemoAccounts, SeedExecution}

  @password "preview-demo-test-password"
  @yaml """
  - user:
      name: demo_author
      type: author
      email: demo-author@example.edu
      given_name: Demo
      family_name: Author
  - institution:
      name: Demo Institution
      country_code: US
      institution_email: institution@example.edu
      institution_url: https://example.edu
  - ownership:
      author: ref:demo_author
      institution: ref:Demo Institution
  - project:
      name: demo_project
      title: Demo Project
      root:
        children: []
  - section:
      name: demo_section
      from: demo_project
  - user:
      name: demo_instructor
      type: instructor
      email: demo-instructor@example.edu
      given_name: Demo
      family_name: Instructor
      email_verified: false
  - enroll:
      user: demo_instructor
      section: demo_section
      role: instructor
  - bulk_create_enroll_users:
      section: demo_section
      prefix: credential_test
      instructors: 1
      learners: 1
  """

  setup do
    previous = System.get_env("PREVIEW_DEMO_USER_PASSWORD")
    System.put_env("PREVIEW_DEMO_USER_PASSWORD", @password)
    on_exit(fn -> restore_env(previous) end)
    :ok
  end

  test "new author, instructor and bulk accounts can use the normal login endpoints" do
    result = execute(DemoAccounts.build(true, @password))

    for {_, account} <- result.state.users do
      assert account.email_confirmed_at
      refute inspect(account) =~ @password

      case account do
        %Author{} ->
          conn =
            post(build_conn(), ~p"/authors/log_in",
              author: %{email: account.email, password: @password}
            )

          assert get_session(conn, :author_token)
          assert redirected_to(conn)

        %User{} ->
          assert account.email_verified
          assert account.independent_learner

          conn =
            post(build_conn(), ~p"/users/log_in",
              user: %{email: account.email, password: @password}
            )

          assert get_session(conn, :user_token)
          assert redirected_to(conn)
      end
    end

    hashes = Enum.map(result.state.users, fn {_, account} -> account.password_hash end)
    assert length(hashes) == 4
    assert Enum.all?(hashes, &is_binary/1)
    assert length(Enum.uniq(hashes)) == length(hashes)
    refute Map.has_key?(result.state.preview_account_defaults, :password)
    refute Map.has_key?(result.state.preview_account_defaults, :password_hash)
    refute inspect(result) =~ @password
  end

  test "absent preview password preserves legacy credentials and confirms generated emails" do
    for value <- [nil, ""] do
      defaults = DemoAccounts.build(true, value)
      refute defaults.password_configured?
      refute Map.has_key?(defaults, :password_hash)
      assert defaults.email_confirmed_at
    end

    result = execute(DemoAccounts.build(true, nil))

    assert Accounts.get_author_by_email_and_password(
             "demo-author@example.edu",
             "temporarypassword123"
           )

    assert User.valid_password?(result.state.users["demo_instructor"], "temporarypassword123")
    assert result.state.users["demo_instructor"].independent_learner

    for name <- ~w(credential_test_instructor_1 credential_test_learner_1) do
      user = result.state.users[name]
      assert user.password_hash == nil
      refute user.independent_learner
      assert user.email_confirmed_at
    end
  end

  test "runtime configuration cannot activate preview credentials in a non-preview artifact" do
    previous = System.get_env("PREVIEW_DEMO_USER_PASSWORD")
    on_exit(fn -> restore_env(previous) end)
    System.put_env("PREVIEW_DEMO_USER_PASSWORD", @password)

    refute Oli.PreviewQATools.Config.preview_build?()
    assert DemoAccounts.defaults() == nil
    assert DemoAccounts.build(false, @password) == nil
    assert DemoAccounts.build(false, "invalid") == nil

    path =
      Path.join(System.tmp_dir!(), "demo-accounts-#{System.unique_integer([:positive])}.yaml")

    File.write!(path, @yaml)
    on_exit(fn -> File.rm(path) end)
    result = SeedExecution.execute_file(path)
    assert result.errors == []
    assert result.state.preview_account_defaults == nil
    assert result.state.users["credential_test_learner_1"].password_hash == nil
    assert result.state.users["credential_test_learner_1"].email_confirmed_at == nil

    assert Accounts.get_author_by_email_and_password(
             "demo-author@example.edu",
             "temporarypassword123"
           )
  end

  test "reused bulk accounts retain their existing password and passwordless state" do
    result = execute(nil)
    instructor = result.state.users["credential_test_instructor_1"]

    instructor =
      instructor
      |> User.password_changeset(%{password: "existing-user-password"})
      |> Repo.update!()

    repeated =
      Scenarios.execute_yaml(
        """
        - bulk_create_enroll_users:
            section: demo_section
            prefix: credential_test
            instructors: 1
            learners: 1
        """,
        state: result.state,
        preview_account_defaults: DemoAccounts.build(true, @password)
      )

    assert repeated.errors == []

    assert repeated.state.scenario_results.bulk_create_enroll_users == %{
             created: 0,
             reused: 2,
             enrolled: 2
           }

    assert Repo.reload!(instructor).password_hash == instructor.password_hash
    assert Repo.reload!(result.state.users["credential_test_learner_1"]).password_hash == nil
  end

  test "colliding explicit accounts fail without changing the existing password or leaking the secret" do
    result = execute(DemoAccounts.build(true, @password))
    original = result.state.users["demo_instructor"]
    new_password = "another-preview-password"
    System.put_env("PREVIEW_DEMO_USER_PASSWORD", new_password)

    log =
      capture_log(fn ->
        collision =
          Scenarios.execute_yaml(
            """
            - user:
                name: collision
                type: instructor
                email: demo-instructor@example.edu
                given_name: Other
                family_name: Instructor
            """,
            state: result.state,
            preview_account_defaults: DemoAccounts.build(true, new_password)
          )

        assert [_] = collision.errors
        refute inspect(collision) =~ new_password
      end)

    refute log =~ new_password
    assert Repo.reload!(original).password_hash == original.password_hash
  end

  test "invalid configured passwords fail with a bounded secret-free error" do
    for password <- ["too-short", String.duplicate("x", 73), String.duplicate("é", 37)] do
      log =
        capture_log(fn ->
          error = assert_raise ArgumentError, fn -> DemoAccounts.build(true, password) end
          assert error.message =~ "PREVIEW_DEMO_USER_PASSWORD"
          refute error.message =~ password
        end)

      refute log =~ password
    end
  end

  test "runtime password reads reject missing or invalid values with the same bounded error" do
    defaults = DemoAccounts.build(true, @password)
    expected = assert_raise ArgumentError, fn -> DemoAccounts.build(true, "too-short") end

    for value <- [nil, "", "too-short", String.duplicate("x", 73), String.duplicate("é", 37)] do
      restore_env(value)

      log =
        capture_log(fn ->
          error = assert_raise ArgumentError, fn -> DemoAccounts.password(defaults) end
          assert error.message == expected.message
        end)

      assert log == ""
    end
  end

  test "runtime password reads use a valid replacement without retaining it in defaults" do
    defaults = DemoAccounts.build(true, @password)
    replacement = "replacement-preview-password"
    System.put_env("PREVIEW_DEMO_USER_PASSWORD", replacement)

    assert DemoAccounts.password(defaults) == replacement
    refute inspect(defaults) =~ replacement
    refute inspect(defaults) =~ @password
  end

  test "omitting defaults preserves inherited preview account behavior" do
    result = execute(DemoAccounts.build(true, @password))
    continued = continue_accounts(result.state, [])

    assert continued.state.preview_account_defaults == result.state.preview_account_defaults

    for name <- ~w(continued_instructor continued_learner_1) do
      user = continued.state.users[name]
      assert User.valid_password?(user, @password)
      assert user.email_confirmed_at
      assert user.email_verified
      assert user.independent_learner
    end
  end

  test "explicit nil clears inherited preview defaults for newly created accounts" do
    result = execute(DemoAccounts.build(true, @password))
    continued = continue_accounts(result.state, preview_account_defaults: nil)

    assert continued.state.preview_account_defaults == nil
    instructor = continued.state.users["continued_instructor"]
    assert User.valid_password?(instructor, "temporarypassword123")
    assert instructor.email_confirmed_at == nil
    refute instructor.email_verified

    learner = continued.state.users["continued_learner_1"]
    assert learner.password_hash == nil
    assert learner.email_confirmed_at == nil
    refute learner.independent_learner
  end

  defp continue_accounts(state, opts) do
    result =
      Scenarios.execute_yaml(
        """
        - user:
            name: continued_instructor
            type: instructor
            email: continued-instructor@example.edu
            given_name: Continued
            family_name: Instructor
            email_verified: false
        - bulk_create_enroll_users:
            section: demo_section
            prefix: continued
            instructors: 0
            learners: 1
        """,
        Keyword.put(opts, :state, state)
      )

    assert result.errors == []
    result
  end

  defp execute(defaults) do
    result = Scenarios.execute_yaml(@yaml, ownership: true, preview_account_defaults: defaults)
    assert result.errors == []
    assert Enum.all?(result.verifications, & &1.passed)
    result
  end

  defp restore_env(nil), do: System.delete_env("PREVIEW_DEMO_USER_PASSWORD")
  defp restore_env(value), do: System.put_env("PREVIEW_DEMO_USER_PASSWORD", value)
end
