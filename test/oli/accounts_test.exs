defmodule Oli.AccountsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Accounts
  alias Oli.Accounts.{User, UserToken}
  alias Oli.Accounts.{Author, AuthorPreferences, User, UserPreferences}
  alias Oli.Groups
  alias Oli.Groups.CommunityAccount
  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Accounts.SystemRole

  describe "authors" do
    test "system role defaults to author", %{} do
      author = author_fixture()

      assert author.system_role_id == Accounts.SystemRole.role_id().author
      assert Accounts.is_admin?(author) == false
    end

    test "changeset accepts system role change", %{} do
      author = author_fixture()

      assert Accounts.is_admin?(author) == false
      assert author.system_role_id == Accounts.SystemRole.role_id().author

      {:ok, author} =
        Accounts.insert_or_update_author(%{
          email: author.email,
          system_role_id: Accounts.SystemRole.role_id().system_admin
        })

      assert author.system_role_id == Accounts.SystemRole.role_id().system_admin
    end

    test "Accounts.is_admin? returns true when the author has and admin role and has_admin_role?/2 returns true when the author has the matching role or system_admin role" do
      author = author_fixture()

      assert Accounts.is_admin?(author) == false
      assert Accounts.has_admin_role?(author, SystemRole.role_id().system_admin) == false
      assert Accounts.has_admin_role?(author, :system_admin) == false
      assert Accounts.has_admin_role?(author, SystemRole.role_id().content_admin) == false
      assert Accounts.has_admin_role?(author, :content_admin) == false
      assert Accounts.has_admin_role?(author, SystemRole.role_id().account_admin) == false
      assert Accounts.has_admin_role?(author, :account_admin) == false

      {:ok, author} =
        Accounts.insert_or_update_author(%{
          email: author.email,
          system_role_id: Accounts.SystemRole.role_id().system_admin
        })

      assert author.system_role_id == Accounts.SystemRole.role_id().system_admin
      assert Accounts.is_admin?(author) == true
      assert Accounts.has_admin_role?(author, SystemRole.role_id().system_admin) == true
      assert Accounts.has_admin_role?(author, :system_admin) == true
      assert Accounts.has_admin_role?(author, SystemRole.role_id().content_admin) == true
      assert Accounts.has_admin_role?(author, :content_admin) == true
      assert Accounts.has_admin_role?(author, SystemRole.role_id().account_admin) == true
      assert Accounts.has_admin_role?(author, :account_admin) == true

      {:ok, author} =
        Accounts.insert_or_update_author(%{
          email: author.email,
          system_role_id: Accounts.SystemRole.role_id().account_admin
        })

      assert author.system_role_id == Accounts.SystemRole.role_id().account_admin
      assert Accounts.is_admin?(author) == true
      assert Accounts.has_admin_role?(author, SystemRole.role_id().system_admin) == false
      assert Accounts.has_admin_role?(author, :system_admin) == false
      assert Accounts.has_admin_role?(author, SystemRole.role_id().content_admin) == false
      assert Accounts.has_admin_role?(author, :content_admin) == false
      assert Accounts.has_admin_role?(author, SystemRole.role_id().account_admin) == true
      assert Accounts.has_admin_role?(author, :account_admin) == true

      {:ok, author} =
        Accounts.insert_or_update_author(%{
          email: author.email,
          system_role_id: Accounts.SystemRole.role_id().content_admin
        })

      assert author.system_role_id == Accounts.SystemRole.role_id().content_admin
      assert Accounts.is_admin?(author) == true
      assert Accounts.has_admin_role?(author, SystemRole.role_id().system_admin) == false
      assert Accounts.has_admin_role?(author, :system_admin) == false
      assert Accounts.has_admin_role?(author, SystemRole.role_id().content_admin) == true
      assert Accounts.has_admin_role?(author, :content_admin) == true
      assert Accounts.has_admin_role?(author, SystemRole.role_id().account_admin) == false
      assert Accounts.has_admin_role?(author, :account_admin) == false
    end

    test "search_authors_matching/1 returns authors matching the input exactly" do
      author = insert(:author)

      [matching_author] = Accounts.search_authors_matching(author.email)

      assert matching_author == %Author{author | email_verified: nil}
    end

    test "search_authors_matching/1 returns nothing when only matching a prefix" do
      author = insert(:author)
      assert [] == Accounts.search_authors_matching(String.slice(author.email, 0..3))
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
        "given_name" => "new given name"
      }

      assert {:ok, author = %Author{}} = Accounts.update_author(author, attrs)
      assert author.email == attrs["email"]
      assert author.family_name == attrs["family_name"]
      assert author.given_name == attrs["given_name"]
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
      author = Oli.AccountsFixtures.author_fixture()

      valid_attrs =
        @valid_attrs
        |> Map.put(:author_id, author.id)

      user = valid_attrs |> user_fixture()

      {:ok, %{user: user, author: author, valid_attrs: valid_attrs}}
    end

    test "get_user!/1 returns the user with given id", %{user: user} do
      assert Accounts.get_user!(user.id).email == user.email
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

      fields = %{
        "sub" => "sub",
        "cognito:username" => "ea06d74d-a1f6-4fdc-a8b3-b4550f9625f1",
        "email" => "email",
        "name" => "username"
      }

      {:ok, author} = Accounts.setup_sso_author(fields, community.id)

      assert author.name == "username"
      assert author.email == "email"

      user = Accounts.get_user_by(%{email: "email"})
      assert user.sub == "sub"
      assert user.preferred_username == "ea06d74d-a1f6-4fdc-a8b3-b4550f9625f1"
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

      assert returned_author == %Author{author | email_verified: nil}

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

    test "bulk_create_invited_users/2" do
      inviter_author = insert(:author)
      invited_users = ["non_existant_user_1@test.com", "non_existant_user_2@test.com"]

      Accounts.bulk_create_invited_users(
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
        "given_name" => "new given name"
      }

      assert {:ok, user = %User{}} = Accounts.update_user(user, attrs)
      assert user.email == attrs["email"]
      assert user.family_name == attrs["family_name"]
      assert user.given_name == attrs["given_name"]
    end

    test "update user password fails when the new password is less than 8 characters long" do
      user = insert(:user)

      attrs = %{
        "current_password" => "password_1",
        "password" => "pass",
        "password_confirmation" => "pass"
      }

      changeset = Accounts.change_user_password(user, attrs)
      assert changeset.valid? == false

      {:password, {error_message, [count: 12, validation: :length, kind: :min, type: :string]}} =
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
                 {"Email has already been taken by another independent learner",
                  [validation: :unsafe_unique, fields: [:email]]}
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

      fields = %{
        "sub" => "sub",
        "name" => "username",
        "email" => user_email,
        "cognito:username" => "ea06d74d-a1f6-4fdc-a8b3-b4550f9625f1"
      }

      {:ok, user, author} = Accounts.setup_sso_user(fields, community.id)

      user_id = user.id
      author_id = author.id

      assert user.sub == "sub"
      assert user.preferred_username == "ea06d74d-a1f6-4fdc-a8b3-b4550f9625f1"
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
      fields = %{"sub" => "sub", "name" => "username", "email" => user_email}

      {:ok, user, author} = Accounts.setup_sso_user(fields, community.id)

      # Ensure the existing user is preserved
      assert user.email == existing_user.email
      # Ensure the existing linked author is preserved
      assert user.author_id == author.id
    end
  end

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_independent_user(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} =
        Accounts.register_independent_user(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.register_independent_user(%{email: too_long, password: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_independent_user(%{email: email})

      assert "Email has already been taken by another independent learner" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_independent_user(%{email: String.upcase(email)})

      assert "Email has already been taken by another independent learner" in errors_on(changeset).email
    end

    test "registers users with a hashed password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_independent_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_binary(user.password_hash)
      assert is_nil(user.email_confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_registration(%User{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_user_email()
      password = valid_user_password()

      changeset =
        Accounts.change_user_registration(
          %User{},
          valid_user_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :password_hash))
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = Accounts.apply_user_email(user, valid_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: user} do
      %{email: email} = user_fixture()
      password = valid_user_password()

      {:error, changeset} = Accounts.apply_user_email(user, password, %{email: email})

      assert "Email has already been taken by another independent learner" in errors_on(changeset).email
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = Accounts.apply_user_email(user, valid_user_password(), %{email: email})
      assert user.email == email
      assert Accounts.get_user!(user.id).email != email
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert Accounts.update_user_email(user, token) == :ok
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      assert changed_user.email_confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_user_email(user, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(%User{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :password_hash))
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, _} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{
        user:
          user_fixture(%{
            email_verified: nil,
            email_confirmed_at: nil
          })
      }
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "confirm_user/1" do
    setup do
      user = user_fixture(%{email_verified: nil, email_confirmed_at: nil})

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: user, token: token} do
      assert {:ok, confirmed_user} = Accounts.confirm_user(token)
      assert confirmed_user.email_confirmed_at
      assert confirmed_user.email_confirmed_at != user.email_confirmed_at
      assert Repo.get!(User, user.id).email_confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert Accounts.confirm_user("oops") == :error
      refute Repo.get!(User, user.id).email_confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_user(token) == :error
      refute Repo.get!(User, user.id).email_confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "reset_password"
    end
  end

  describe "get_user_by_reset_password_token/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: id)
    end

    test "does not return the user with invalid token", %{user: user} do
      refute Accounts.get_user_by_reset_password_token("oops")
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not return the user if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.reset_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_user_password(user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} = Accounts.reset_user_password(user, %{password: "new valid password"})
      assert is_nil(updated_user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)
      {:ok, _} = Accounts.reset_user_password(user, %{password: "new valid password"})
      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
