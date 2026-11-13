defmodule Oli.Accounts.AuditedIdentityTest do
  use Oli.DataCase, async: true

  import Oli.Factory

  alias Ecto.Multi
  alias Oli.Accounts
  alias Oli.Accounts.{Audited, Author, AuthorToken, User, UserToken}
  alias Oli.Auditing.{Context, LogEvent}
  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @password "a valid password 123"

  describe "account creation" do
    test "self-registration records account_created with the new account as actor" do
      {:ok, %User{} = user} =
        Accounts.register_independent_user(%{
          email: "registered@example.edu",
          given_name: "Reg",
          family_name: "Istered",
          password: @password,
          password_confirmation: @password
        })

      assert [event] = events(:account_created)
      assert event.actor_type == :user
      assert event.user_id == user.id
      assert event.affected_user_id == user.id
      assert event.event_key == "account:primary:created"
      assert event.details == %{"creation_source" => "self_registration"}

      assert event.changes["email"] == %{
               "operation" => "set",
               "after" => "registered@example.edu"
             }

      refute_secret(event, @password)
      refute_secret(event, user.password_hash)
    end

    test "a guest is created by itself" do
      {:ok, %User{guest: true} = guest} = Accounts.create_guest_user()

      assert [event] = events(:account_created)
      assert event.user_id == guest.id
      assert event.details["creation_source"] == "guest"
    end

    test "invitations record the inviter as actor" do
      inviter = insert(:author)
      context = Context.for_actor(inviter, source: :ui)

      {:ok, %Author{} = invited} = Audited.invite_author(context, "invited@example.edu")

      {:ok, %{users: {2, users}}} =
        Multi.new()
        |> Audited.invite_users_multi(:users, context, ["one@example.edu", "two@example.edu"])
        |> Repo.transaction()

      events = events(:account_created)
      assert length(events) == 3
      assert Enum.all?(events, &(&1.author_id == inviter.id))
      assert Enum.all?(events, &(&1.details["creation_source"] == "invitation"))
      assert Enum.any?(events, &(&1.affected_author_id == invited.id))

      assert Enum.sort(Enum.map(users, & &1.id)) ==
               events |> Enum.map(& &1.affected_user_id) |> Enum.reject(&is_nil/1) |> Enum.sort()
    end

    test "accepting an invitation records the invitee's own update" do
      context = Context.for_actor(insert(:author), source: :ui)
      {:ok, invited} = Audited.invite_author(context, "accept@example.edu")

      {:ok, accepted} =
        Accounts.accept_author_invitation(invited, %{
          "given_name" => "Ac",
          "family_name" => "Cepted",
          "password" => @password,
          "password_confirmation" => @password
        })

      assert accepted.invitation_accepted_at
      assert [event] = events(:account_updated)
      assert event.author_id == invited.id
      assert event.changes["password"] == Oli.Auditing.Changes.secret_record()
      assert Map.has_key?(event.changes, "invitation_accepted_at")
      refute_secret(event, @password)
    end
  end

  describe "passwords and recovery" do
    setup do
      user = user_fixture()
      session = Accounts.generate_user_session_token(user)
      %{user: user, session: session, context: Context.for_actor(user, source: :ui)}
    end

    test "change_password records the marker and the revoked sessions", %{
      user: user,
      context: context
    } do
      {:ok, _} =
        Audited.change_password(context, user, valid_user_password(), %{
          current_password: valid_user_password(),
          password: @password,
          password_confirmation: @password
        })

      assert [updated] = events(:account_updated)
      assert updated.changes == %{"password" => Oli.Auditing.Changes.secret_record()}
      assert [revoked] = events(:session_revoked)
      assert revoked.details == %{"revoked_count" => 1}
      assert revoked.operation_id == updated.operation_id
      refute Repo.get_by(UserToken, user_id: user.id)
      refute_secret(updated, @password)
    end

    test "a wrong current password writes nothing", %{user: user, context: context} do
      assert {:error, %Ecto.Changeset{}} =
               Audited.change_password(context, user, "wrong password", %{password: @password})

      assert all_events(user) == []
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "only the account itself can change or reset its password", %{user: user} do
      other = Context.for_actor(insert(:author), source: :ui)

      assert {:error, :invalid_request} =
               Audited.change_password(other, user, valid_user_password(), %{password: @password})

      assert {:error, :invalid_request} =
               Audited.reset_password(other, user, %{password: @password})

      assert {:error, :invalid_request} =
               Audited.create_password(other, user, %{password: @password})
    end

    test "create_password refuses an account that already has one", %{
      user: user,
      context: context
    } do
      assert {:error, :invalid_request} =
               Audited.create_password(context, user, %{password: @password})

      assert all_events(user) == []
    end

    test "a reset records account_credential_recovered and no token", %{user: user} do
      unauthenticated = Context.for_system(:unauthenticated_request, source: :ui)

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(unauthenticated, user, url)
        end)

      assert [requested] = events(:account_recovery_requested)
      assert requested.actor_type == :system
      assert requested.actor_key == "unauthenticated_request"
      assert requested.affected_user_id == user.id
      assert requested.details == %{"recovery_kind" => "password_reset"}
      refute_secret(requested, token)

      {:ok, _} =
        Audited.reset_password(Context.for_actor(user, source: :ui), user, %{password: @password})

      assert [recovered] = events(:account_credential_recovered)
      assert recovered.user_id == user.id
      assert recovered.changes == %{"password" => Oli.Auditing.Changes.secret_record()}
      assert [_revoked] = events(:session_revoked)
      refute Accounts.get_user_by_reset_password_token(token)
    end

    test "an administrator's reset link names the administrator", %{user: user} do
      admin = insert(:author)

      {:ok, encoded} =
        Audited.request_recovery(
          Context.for_actor(admin, source: :ui),
          {:user, user},
          :admin_reset_link
        )

      assert Accounts.get_user_by_reset_password_token(encoded).id == user.id
      assert [event] = events(:account_recovery_requested)
      assert event.author_id == admin.id
      assert event.details == %{"recovery_kind" => "admin_reset_link"}
    end
  end

  describe "confirmation and email change" do
    test "a confirmation token confirms once" do
      user = user_fixture(%{email_confirmed_at: nil})
      context = Context.for_actor(user, source: :ui)

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(context, user, url)
        end)

      assert {:ok, %User{email_confirmed_at: %DateTime{}}} = Audited.confirm_email(:user, token)
      assert :error = Audited.confirm_email(:user, token)

      assert [event] = events(:account_updated)
      assert event.user_id == user.id
      assert %{"email_confirmed_at" => %{"before" => nil}} = event.changes
    end

    test "an email change applies the confirmed address" do
      author = insert(:author)
      context = Context.for_actor(author, source: :ui)

      {encoded, token} =
        AuthorToken.build_email_token(
          %{author | email: "new@example.edu"},
          "change:#{author.email}"
        )

      Repo.insert!(token)

      assert :ok = Audited.confirm_email_change(context, author, encoded)
      assert Repo.get!(Author, author.id).email == "new@example.edu"

      assert [event] = events(:account_updated)

      assert event.changes["email"] == %{
               "operation" => "set",
               "before" => author.email,
               "after" => "new@example.edu"
             }

      assert :error = Audited.confirm_email_change(context, author, encoded)
    end
  end

  describe "identity-provider provisioning and linking" do
    test "LTI provisioning creates once and records only real changes" do
      institution = insert(:institution)

      claims = %{
        sub: "lti-sub-1",
        given_name: "Lti",
        family_name: "User",
        email: "lti@example.edu",
        lti_institution_id: institution.id
      }

      {:ok, user} = Accounts.insert_or_update_lms_user(claims, institution.id)
      {:ok, again} = Accounts.insert_or_update_lms_user(claims, institution.id)
      assert again.id == user.id

      {:ok, _} =
        Accounts.insert_or_update_lms_user(%{claims | given_name: "Renamed"}, institution.id)

      assert [created] = events(:account_created)
      assert created.actor_key == "provider_provisioning"
      assert created.affected_user_id == user.id
      assert created.details == %{"creation_source" => "lti"}

      assert [updated] = events(:account_updated)
      assert updated.changes["given_name"]["after"] == "Renamed"
    end

    test "linking and unlinking record account_linked" do
      user = insert(:user, author: nil)
      author = insert(:author)
      context = Context.for_actor(user, source: :ui)

      {:ok, _} = Audited.link_accounts(context, user.id, author.id)
      {:ok, _} = Audited.link_accounts(context, user.id, author.id)
      {:ok, unlinked} = Audited.unlink_accounts(context, user.id)

      assert is_nil(unlinked.author_id)
      assert [linked, removed] = events(:account_linked)
      assert linked.event_key == "account:primary:linked"

      assert linked.changes == %{
               "author_id" => %{"operation" => "set", "before" => nil, "after" => author.id}
             }

      assert removed.changes["author_id"]["after"] == nil
    end

    test "Cognito setup records the user, the author, and their link" do
      community = insert(:community)

      claims = %{
        "sub" => "cognito-sub-1",
        "cognito:username" => "cognito_user",
        "email" => "cognito@example.edu",
        "name" => "Cognito User"
      }

      {:ok, user, author} = Accounts.setup_sso_user(claims, community.id)

      created = events(:account_created)
      assert Enum.all?(created, &(&1.actor_key == "provider_provisioning"))
      assert Enum.any?(created, &(&1.affected_user_id == user.id))
      assert Enum.any?(created, &(&1.affected_author_id == author.id))
      assert [link] = events(:account_linked)
      assert link.affected_user_id == user.id
    end
  end

  describe "login-provider identities" do
    alias Oli.AssentAuth.UserAssentAuth

    test "connecting and disconnecting a provider records the provider, not its uid" do
      user = user_fixture()

      {:ok, _identity} =
        UserAssentAuth.add_identity_provider(user, %{
          "provider" => "google",
          "uid" => "google-uid-123",
          "email" => "ignored@example.edu"
        })

      assert [linked] = events(:account_identity_linked)
      assert linked.user_id == user.id
      assert linked.affected_user_id == user.id
      assert linked.details == %{"provider" => "google"}
      refute_secret(linked, "google-uid-123")

      user = UserAssentAuth.get_user_with_identities(user.id)

      {:ok, {1, nil}} =
        user.user_identities
        |> Enum.split_with(&(&1.provider == "google"))
        |> UserAssentAuth.delete_identity_providers(user)

      assert [unlinked] = events(:account_identity_unlinked)
      assert unlinked.details == %{"provider" => "google"}
    end

    test "only identities of the account are removed and recorded" do
      user = user_fixture()
      other = user_fixture()

      {:ok, own} =
        UserAssentAuth.add_identity_provider(user, %{"provider" => "google", "uid" => "own-1"})

      {:ok, foreign} =
        UserAssentAuth.add_identity_provider(other, %{"provider" => "github", "uid" => "other-1"})

      assert {:ok, {1, nil}} =
               Audited.unlink_identities(Context.for_actor(user, source: :ui), user, [
                 own,
                 foreign
               ])

      assert [event] = events(:account_identity_unlinked)
      assert event.details == %{"provider" => "google"}
      assert Repo.get(Oli.AssentAuth.UserIdentity, foreign.id)
    end

    test "the last provider of an account without a password cannot be removed" do
      user = insert(:user, password_hash: nil)

      {:ok, _} =
        UserAssentAuth.add_identity_provider(user, %{"provider" => "github", "uid" => "gh-1"})

      user = UserAssentAuth.get_user_with_identities(user.id)

      assert {:error, {:no_password, _changeset}} =
               user.user_identities
               |> Enum.split_with(&(&1.provider == "github"))
               |> UserAssentAuth.delete_identity_providers(user)

      assert events(:account_identity_unlinked) == []
    end
  end

  describe "Scenario bootstrap" do
    test "user directives create accounts under the Playwright setup actor" do
      yaml = """
      - user:
          name: scenario_author
          type: author
          email: scenario-author@example.edu
          given_name: Scenario
          family_name: Author
      - user:
          name: scenario_student
          type: student
          email: scenario-student@example.edu
          given_name: Scenario
          family_name: Student
      """

      result = Scenarios.execute_yaml(yaml, RuntimeOpts.build())
      assert result.errors == []

      created = events(:account_created)
      emails = Enum.map(created, & &1.entity_snapshot["email"])
      assert "scenario-author@example.edu" in emails
      assert "scenario-student@example.edu" in emails

      assert Enum.all?(created, fn event ->
               event.actor_key == "playwright_setup" and event.source == :scenario and
                 event.details["creation_source"] == "scenario"
             end)
    end
  end

  defp events(event_type),
    do: Repo.all(from(e in LogEvent, where: e.event_type == ^event_type, order_by: e.id))

  defp all_events(%Oli.Accounts.User{id: id}),
    do: Repo.all(from(e in LogEvent, where: e.affected_user_id == ^id))

  defp all_events(%Oli.Accounts.Author{id: id}),
    do: Repo.all(from(e in LogEvent, where: e.affected_author_id == ^id))

  defp refute_secret(event, secret) when is_binary(secret) do
    json =
      event |> Map.take([:changes, :details, :entity_snapshot, :search_text]) |> Jason.encode!()

    refute json =~ secret
  end
end
