defmodule Oli.AccountsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Accounts
  alias Oli.Accounts.{Author, AuthorPreferences, User, UserPreferences}
  alias Oli.Groups
  alias Oli.Groups.CommunityAccount
  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.ContextRoles

  describe "authors" do
    test "system role defaults to author", %{} do
      {:ok, author} =
        Author.changeset(%Author{}, %{
          email: "user#{System.unique_integer([:positive])}@example.com",
          given_name: "Test",
          family_name: "User",
          password: "password123",
          password_confirmation: "password123"
        })
        |> Repo.insert()

      assert author.system_role_id == Accounts.SystemRole.role_id().author
      assert Accounts.is_system_admin?(author) == false
    end

    test "changeset accepts system role change", %{} do
      {:ok, author} =
        Author.noauth_changeset(%Author{}, %{
          email: "user#{System.unique_integer([:positive])}@example.com",
          given_name: "Test",
          family_name: "User",
          password: "password123",
          password_confirmation: "password123"
        })
        |> Repo.insert()

      assert Accounts.is_system_admin?(author) == false

      {:ok, author} =
        Accounts.insert_or_update_author(%{
          email: author.email,
          system_role_id: Accounts.SystemRole.role_id().system_admin
        })

      assert author.system_role_id == Accounts.SystemRole.role_id().system_admin
      assert Accounts.is_system_admin?(author) == true
    end

    test "search_authors_matching/1 returns authors matching the input exactly" do
      author = insert(:author)
      assert [author] == Accounts.search_authors_matching(author.email)
    end

    test "search_authors_matching/1 returns nothing when only matching a prefix" do
      author = insert(:author)
      assert [] == Accounts.search_authors_matching(String.slice(author.email, 0..3))
    end

    test "user_confirmation_pending?/1 returns true when author has not a confirmed account" do
      non_confirmed_author = insert(:author, email_confirmation_token: "token")
      assert Accounts.user_confirmation_pending?(non_confirmed_author)
    end

    test "user_confirmation_pending?/1 returns false when author has a confirmed account" do
      confirmed_author = insert(:author, email_confirmed_at: Timex.now())
      refute Accounts.user_confirmation_pending?(confirmed_author)
    end

    test "get_author_preference/3 returns an author preference" do
      author = insert(:author)

      assert Accounts.get_author_preference(author, :timezone) == "America/New_York"
    end

    test "get_author_preference/3 fetches an author by id and returns the preference" do
      author = insert(:author)

      assert Accounts.get_author_preference(author.id, :timezone) == "America/New_York"
    end

    test "get_author_preference/3 returns the default value when no preference was set" do
      author = insert(:author, preferences: %AuthorPreferences{})

      assert Accounts.get_author_preference(author, :timezone, "default") == "default"
    end

    test "set_author_preference/3 sets an author preference" do
      author = insert(:author)

      assert {:ok, author} =
               Accounts.set_author_preference(author, :timezone, "America/Los_Angeles")

      assert author.preferences.timezone == "America/Los_Angeles"
    end

    test "set_author_preference/3 fetches an author by id and sets the preference" do
      author = insert(:author)

      assert {:ok, author} =
               Accounts.set_author_preference(author.id, :timezone, "America/Los_Angeles")

      assert author.preferences.timezone == "America/Los_Angeles"
    end

    test "update author data from edit account form successfully" do
      author = insert(:author)

      attrs = %{
        "current_password" => "password_1",
        "email" => "new_email@example.com",
        "family_name" => "new family name",
        "given_name" => "new given name",
        "password" => "password_2",
        "password_confirmation" => "password_2"
      }

      assert {:ok, author = %Author{}} = Accounts.update_author(author, attrs)
      assert author.email == attrs["email"]
      assert author.family_name == attrs["family_name"]
      assert author.given_name == attrs["given_name"]
      assert Bcrypt.verify_pass(attrs["password"], author.password_hash)
    end

    test "update author password fails when new password and password confirmation are different" do
      author = insert(:author)

      attrs = %{
        "current_password" => "password_1",
        "password" => "password_22",
        "password_confirmation" => "password_2"
      }

      assert {:error, changeset} = Accounts.update_author(author, attrs)
      assert changeset.valid? == false

      {:password_confirmation, {error_message, [validation: :confirmation]}} =
        List.first(changeset.errors)

      assert error_message == "does not match confirmation"
    end

    test "update author password fails when the new password is less than 8 characters long" do
      author = insert(:author)

      attrs = %{
        "current_password" => "password_1",
        "password" => "pass",
        "password_confirmation" => "pass"
      }

      assert {:error, changeset} = Accounts.update_author(author, attrs)
      assert changeset.valid? == false

      {:password, {error_message, [count: 8, validation: :length, kind: :min, type: :string]}} =
        List.first(changeset.errors)

      assert error_message =~ "should be at least %{count} character(s)"
    end

    test "update author data with an email used by another author fails" do
      author_1 = insert(:author)
      author_2 = insert(:author)

      attrs = %{
        "email" => author_1.email,
        "current_password" => "password_1",
        "password" => "password_2",
        "password_confirmation" => "password_2"
      }

      assert {:error, changeset = %Ecto.Changeset{}} = Accounts.update_author(author_2, attrs)
      assert changeset.valid? == false

      assert changeset.errors == [
               email:
                 {"has already been taken",
                  [constraint: :unique, constraint_name: "authors_email_index"]}
             ]
    end
  end

  describe "users" do
    alias Oli.Accounts.User

    @valid_attrs %{
      email: "some_email@example.com",
      email_confirmation: "some_email@example.com",
      given_name: "some given_name",
      family_name: "some family_name",
      sub: "some sub",
      picture: "some picture",
      password: "some_pass123",
      password_confirmation: "some_pass123",
      age_verified: true
    }
    @update_attrs %{
      email: "some_updated_email@example.com",
      given_name: "some updated given_name",
      family_name: "some updated family_name",
      sub: "some updated sub",
      picture: "some updated picture",
      password: "some_pass123",
      password_confirmation: "some_pass123"
    }
    @invalid_attrs %{email: nil, given_name: nil, family_name: nil, sub: nil, picture: nil}

    setup do
      author = author_fixture()

      valid_attrs =
        @valid_attrs
        |> Map.put(:author_id, author.id)

      {:ok, user} = valid_attrs |> Accounts.create_user()

      {:ok, %{user: user, author: author, valid_attrs: valid_attrs}}
    end

    test "get_user!/1 returns the user with given id", %{user: user} do
      assert Accounts.get_user!(user.id).email == user.email
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "verification_changeset/2 runs age verification check when enabled" do
      Config.Reader.read!("test/config/age_verification_config.exs")
      |> Application.put_all_env()

      assert %Ecto.Changeset{
               errors: [
                 age_verified:
                   {"You must verify you are old enough to access our site in order to continue",
                    [validation: :acceptance]}
               ]
             } =
               User.verification_changeset(
                 %User{},
                 Map.merge(@valid_attrs, %{
                   age_verified: false
                 })
               )

      assert %Ecto.Changeset{errors: []} = User.verification_changeset(%User{}, @valid_attrs)

      Config.Reader.read!("test/config/config.exs")
      |> Application.put_all_env()

      assert %Ecto.Changeset{errors: []} =
               User.verification_changeset(
                 %User{},
                 Map.merge(@valid_attrs, %{
                   age_verified: false
                 })
               )
    end

    test "update_user/2 with valid data updates the user", %{user: user} do
      assert {:ok, %User{} = user} = Accounts.update_user(user, @update_attrs)
      assert user.email == "some_updated_email@example.com"
      assert user.given_name == "some updated given_name"
      assert user.family_name == "some updated family_name"
      assert user.sub == "some updated sub"
      assert user.picture == "some updated picture"
    end

    test "update_user/2 with invalid data returns error changeset", %{user: user} do
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user.email == Accounts.get_user!(user.id).email
    end

    test "delete_user/1 deletes the user", %{user: user} do
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "update_user_platform_roles/2 updates a users platform roles", %{user: user} do
      user = Repo.preload(user, [:platform_roles])
      assert user.platform_roles == []

      updated_roles = [
        Lti_1p3.Tool.PlatformRoles.get_role(:system_administrator),
        Lti_1p3.Tool.PlatformRoles.get_role(:institution_instructor)
      ]

      {:ok, _user} = Accounts.update_user_platform_roles(user, updated_roles)

      user = Accounts.get_user!(user.id, preload: [:platform_roles])

      assert Lti_1p3.Tool.PlatformRoles.has_roles?(
               user,
               [
                 Lti_1p3.Tool.PlatformRoles.get_role(:system_administrator),
                 Lti_1p3.Tool.PlatformRoles.get_role(:institution_instructor)
               ],
               :all
             )
    end

    test "get_author_with_community_admin_count/1 returns the author with the community_admin_count as zero" do
      author = insert(:author)

      assert %Author{community_admin_count: 0} =
               Accounts.get_author_with_community_admin_count(author.id)
    end

    test "get_author_with_community_admin_count/1 returns the author with the community_admin_count field populated" do
      community_account = insert(:community_account)
      insert(:community_account, %{author: community_account.author})
      insert(:community_account, %{author: community_account.author, is_admin: false})

      assert %Author{community_admin_count: 2} =
               Accounts.get_author_with_community_admin_count(community_account.author_id)
    end

    test "setup_sso_user/3 returns the created user and associates it to the given community" do
      community = insert(:community)
      fields = %{"sub" => "sub", "cognito:username" => "username", "email" => "email"}
      {:ok, user, _author} = Accounts.setup_sso_user(fields, community.id)

      assert user.sub == "sub"
      assert user.preferred_username == "username"
      assert user.email == "email"
      assert user.can_create_sections

      assert %CommunityAccount{} =
               Groups.get_community_account_by!(%{user_id: user.id, community_id: community.id})
    end

    test "setup_sso_user/3 returns an error and rollbacks the insertions when data is invalid" do
      fields = %{"sub" => "sub", "cognito:username" => "username", "email" => "email"}

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  community_id:
                    {"does not exist",
                     [
                       constraint: :foreign,
                       constraint_name: "communities_accounts_community_id_fkey"
                     ]}
                ]
              }} = Accounts.setup_sso_user(fields, 0)

      refute Accounts.get_user_by(%{sub: "sub", email: "email"})
    end

    test "setup_sso_author/2 creates author and user if do not exist and associates user to the given community" do
      community = insert(:community)
      fields = %{"sub" => "sub", "cognito:username" => "username", "email" => "email"}
      {:ok, author} = Accounts.setup_sso_author(fields, community.id)

      assert author.name == "username"
      assert author.email == "email"

      user = Accounts.get_user_by(%{email: "email"})
      assert user.sub == "sub"
      assert user.preferred_username == "username"
      assert user.email == "email"
      assert user.can_create_sections

      assert %CommunityAccount{} =
               Groups.get_community_account_by!(%{user_id: user.id, community_id: community.id})

      assert user.author_id == author.id
    end

    test "setup_sso_author/2 links user with author when they have the same email" do
      community = insert(:community)
      user = insert(:user)
      author = insert(:author, email: user.email)

      fields = %{"sub" => user.sub, "cognito:username" => "username", "email" => user.email}
      {:ok, returned_author} = Accounts.setup_sso_author(fields, community.id)

      assert returned_author == author

      returned_user = Accounts.get_user_by(%{email: user.email})
      assert returned_user.email == user.email
      assert returned_user.author_id == returned_author.id
    end

    test "is_lms_user?/1 returns true when the user exists and belongs to an lms" do
      user = insert(:user, %{email: "test@test.com", independent_learner: false})
      insert(:lti_params, user_id: user.id)

      assert Accounts.is_lms_user?(user.email)
    end

    test "is_lms_user?/1 returns true when more than one user email exists and one is lms" do
      user1 = insert(:user, %{email: "test@test.com", independent_learner: false})
      insert(:lti_params, user_id: user1.id)

      _user2 = insert(:user, %{email: "test@test.com", independent_learner: false})

      assert Accounts.is_lms_user?(user1.email)
    end

    test "is_lms_user?/1 returns true when more than one user email exists and all are lms" do
      user1 = insert(:user, %{email: "test@test.com", independent_learner: false})
      insert(:lti_params, user_id: user1.id)

      user2 = insert(:user, %{email: "test@test.com", independent_learner: false})
      insert(:lti_params, user_id: user2.id)

      assert Accounts.is_lms_user?(user1.email)
    end

    test "is_lms_user?/1 returns false only user is independent" do
      user1 = insert(:user, %{email: "test@test.com", independent_learner: true})

      refute Accounts.is_lms_user?(user1.email)
    end

    test "is_lms_user?/1 returns false when the user does not exist" do
      refute Accounts.is_lms_user?("invalid_email")
    end

    test "is_lms_user?/1 returns false when the user exists but is not from an lms" do
      user = insert(:user, %{email: "test@test.com", independent_learner: true})

      refute Accounts.is_lms_user?(user.email)
    end

    test "get_user_preference/3 returns an user preference" do
      user = insert(:user)

      assert Accounts.get_user_preference(user, :timezone) == "America/New_York"
    end

    test "get_user_preference/3 fetches an user by id and returns the preference" do
      user = insert(:user)

      assert Accounts.get_user_preference(user.id, :timezone) == "America/New_York"
    end

    test "get_user_preference/3 returns the default value when no preference was set" do
      user = insert(:user, preferences: %UserPreferences{})

      assert Accounts.get_user_preference(user, :timezone, "default") == "default"
    end

    test "set_user_preference/3 sets an user preference" do
      user = insert(:user)

      assert {:ok, user} = Accounts.set_user_preference(user, :timezone, "America/Los_Angeles")
      assert user.preferences.timezone == "America/Los_Angeles"
    end

    test "set_user_preference/3 fetches an user by id and sets the preference" do
      user = insert(:user)

      assert {:ok, user} = Accounts.set_user_preference(user.id, :timezone, "America/Los_Angeles")
      assert user.preferences.timezone == "America/Los_Angeles"
    end

    test "update_user_context_role/2 updates the context role for a specific enrollment" do
      user = insert(:user)
      section = insert(:section)

      {:ok, enrollment} =
        Sections.enroll(user.id, section.id, [
          Lti_1p3.Tool.ContextRoles.get_role(:context_learner)
        ])

      user_role_id = Sections.get_user_role_from_enrollment(enrollment)

      assert user_role_id == 4

      Accounts.update_user_context_role(
        enrollment,
        ContextRoles.get_role(:context_instructor)
      )

      enrollment = Sections.get_enrollment(section.slug, user.id)

      user_role_id_changed = Sections.get_user_role_from_enrollment(enrollment)

      refute user_role_id_changed == 4
      assert user_role_id_changed == 3
    end

    test "get_users_by_email/1 returns the users from a list of emails" do
      insert(:user, %{email: "user_with_email_1@test.com"})
      insert(:user, %{email: "user_with_email_2@test.com"})
      insert(:user, %{email: "user_with_email_3@test.com"})

      assert Accounts.get_users_by_email([
               "user_with_email_1@test.com",
               "user_with_email_2@test.com",
               "non_existan@test.com"
             ])
             |> Enum.map(& &1.email) == [
               "user_with_email_1@test.com",
               "user_with_email_2@test.com"
             ]
    end

    test "bulk_invite_users/2" do
      inviter_author = insert(:author)
      invited_users = ["non_existant_user_1@test.com", "non_existant_user_2@test.com"]

      Accounts.bulk_invite_users(
        ["non_existant_user_1@test.com", "non_existant_user_2@test.com"],
        inviter_author
      )

      users =
        User
        |> where([u], u.email in ^invited_users)
        |> select([u], [:invitation_token])
        |> Repo.all()

      assert length(users) == 2

      assert Enum.all?(
               users,
               &(!is_nil(&1.invitation_token))
             )
    end

    test "update user data from edit account form successfully" do
      user = insert(:user)

      attrs = %{
        "current_password" => "password_1",
        "email" => "new_email@example.com",
        "family_name" => "new family name",
        "given_name" => "new given name",
        "password" => "password_2",
        "password_confirmation" => "password_2"
      }

      assert {:ok, user = %User{}} = Accounts.update_user(user, attrs)
      assert user.email == attrs["email"]
      assert user.family_name == attrs["family_name"]
      assert user.given_name == attrs["given_name"]
      assert Bcrypt.verify_pass(attrs["password"], user.password_hash)
    end

    test "update user password fails when new password and password confirmation are different" do
      user = insert(:user)

      attrs = %{
        "current_password" => "password_1",
        "password" => "password_22",
        "password_confirmation" => "password_2"
      }

      assert {:error, changeset} = Accounts.update_user(user, attrs)
      assert changeset.valid? == false

      {:password_confirmation, {error_message, [validation: :confirmation]}} =
        List.first(changeset.errors)

      assert error_message == "does not match confirmation"
    end

    test "update user password fails when the new password is less than 8 characters long" do
      user = insert(:user)

      attrs = %{
        "current_password" => "password_1",
        "password" => "pass",
        "password_confirmation" => "pass"
      }

      assert {:error, changeset} = Accounts.update_user(user, attrs)
      assert changeset.valid? == false

      {:password, {error_message, [count: 8, validation: :length, kind: :min, type: :string]}} =
        List.first(changeset.errors)

      assert error_message =~ "should be at least %{count} character(s)"
    end

    test "update user data with an email used by another user fails" do
      user_1 = insert(:user)
      user_2 = insert(:user)

      attrs = %{
        "email" => user_1.email,
        "current_password" => "password_1",
        "password" => "password_2",
        "password_confirmation" => "password_2"
      }

      assert {:error, changeset = %Ecto.Changeset{}} = Accounts.update_user(user_2, attrs)
      assert changeset.valid? == false

      assert changeset.errors == [
               email:
                 {"has already been taken",
                  [constraint: :unique, constraint_name: "users_email_independent_learner_index"]}
             ]
    end
  end

  describe "communities accounts" do
    alias Oli.Groups.Community

    test "list_admin_communities/1 returns the communities for which the author is an admin" do
      community_account = insert(:community_account)
      insert(:community_account, %{author: community_account.author})
      insert(:community_account, %{author: community_account.author, is_admin: false})

      communties = Accounts.list_admin_communities(community_account.author_id)

      assert [%Community{} | _tail] = communties
      assert 2 = length(communties)
    end
  end

  describe "user roles" do
    test "list all context/platform roles for a given user" do
      user = insert(:user)
      section = insert(:section)

      Sections.enroll(user.id, section.id, [
        Lti_1p3.Tool.ContextRoles.get_role(:context_learner)
      ])

      Accounts.update_user_platform_roles(user, [
        Lti_1p3.Tool.PlatformRoles.get_role(:institution_instructor),
        Lti_1p3.Tool.PlatformRoles.get_role(:institution_student)
      ])

      user_roles = Accounts.user_roles(user.id) |> Enum.map(& &1.uri)
      assert Lti_1p3.Tool.ContextRoles.get_role(:context_learner).uri in user_roles
      assert Lti_1p3.Tool.PlatformRoles.get_role(:institution_instructor).uri in user_roles
      assert Lti_1p3.Tool.PlatformRoles.get_role(:institution_student).uri in user_roles
    end
  end

  describe "setup_sso_user/2" do
    test "creates both a user and an author, and links them together" do
      user_email = "user@email.com"
      community = insert(:community)
      fields = %{"sub" => "sub", "cognito:username" => "username", "email" => user_email}

      {:ok, user, author} = Accounts.setup_sso_user(fields, community.id)

      user_id = user.id
      author_id = author.id

      assert user.sub == "sub"
      assert user.preferred_username == "username"
      assert user.email == user_email
      assert user.can_create_sections

      assert %CommunityAccount{user_id: ^user_id} =
               Groups.get_community_account_by!(%{user_id: user_id, community_id: community.id})

      assert Accounts.get_user!(user_id).author_id == author_id
      assert author.name == "username"
      assert author.email == user_email
      assert author.email_confirmed_at

      # Ensure the author is linked to the user
      assert user.author_id == author_id
    end

    test "preserves the existing association that a user has with their linked author" do
      user_email = "user@email.com"
      author_email = "author@email.com"
      existing_author = insert(:author, email: author_email)
      existing_user = insert(:user, email: user_email, author: existing_author, sub: "sub")

      community = insert(:community)
      fields = %{"sub" => "sub", "cognito:username" => "username", "email" => user_email}

      {:ok, user, author} = Accounts.setup_sso_user(fields, community.id)

      # Ensure the existing user is preserved
      assert user.email == existing_user.email
      # Ensure the existing linked author is preserved
      assert user.author_id == author.id
    end
  end
end
