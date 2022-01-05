defmodule Oli.AccountsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Accounts
  alias Oli.Accounts.Author

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
      assert Accounts.is_admin?(author) == false
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

      assert Accounts.is_admin?(author) == false

      {:ok, author} =
        Accounts.insert_or_update_author(%{
          email: author.email,
          system_role_id: Accounts.SystemRole.role_id().admin
        })

      assert author.system_role_id == Accounts.SystemRole.role_id().admin
      assert Accounts.is_admin?(author) == true
    end

    test "search_authors_matching/1 returns authors matching the input exactly" do
      author = insert(:author)
      assert [author] == Accounts.search_authors_matching(author.email)
    end

    test "search_authors_matching/1 returns nothing when only matching a prefix" do
      author = insert(:author)
      assert [] == Accounts.search_authors_matching(String.slice(author.email, 0..3))
    end
  end

  describe "users" do
    alias Oli.Accounts.User

    @valid_attrs %{
      email: "some_email@example.com",
      given_name: "some given_name",
      family_name: "some family_name",
      sub: "some sub",
      picture: "some picture",
      password: "some_pass123",
      password_confirmation: "some_pass123"
    }
    @update_attrs %{
      email: "some_updated_email@example.com",
      given_name: "some updated given_name",
      family_name: "some updated family_name",
      sub: "some updated sub",
      picture: "some updated picture"
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
end
