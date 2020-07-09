defmodule Oli.AccountsTest do
  use Oli.DataCase

  alias Oli.Accounts
  alias Oli.Accounts.Author

  describe "authors" do

    test "system role defaults to author", %{} do

      {:ok, author} = Author.changeset(%Author{}, %{
        email: "ironman#{System.unique_integer([:positive])}@example.com",
        first_name: "Tony",
        last_name: "Stark",
        token: "2u9dfh7979hfd",
        provider: "google",
      })
      |> Repo.insert()

      assert author.system_role_id == Accounts.SystemRole.role_id.author
    end

    test "changeset accepts system role change", %{} do
      {:ok, author} = Author.changeset(%Author{}, %{
        email: "ironman#{System.unique_integer([:positive])}@example.com",
        first_name: "Tony",
        last_name: "Stark",
        token: "2u9dfh7979hfd",
        provider: "google",
      })
      |> Repo.insert()

      {:ok , author} = Accounts.insert_or_update_author(%{email: author.email, system_role_id: Accounts.SystemRole.role_id.admin})

      assert author.system_role_id == Accounts.SystemRole.role_id.admin
    end
  end

  describe "users" do
    alias Oli.Accounts.User

    @valid_attrs %{email: "some email", first_name: "some first_name", last_name: "some last_name", user_id: "some user_id", user_image: "some user_image", roles: "some roles"}
    @update_attrs %{email: "some updated email", first_name: "some updated first_name", last_name: "some updated last_name", user_id: "some updated user_id", user_image: "some updated user_image", roles: "some updated roles"}
    @invalid_attrs %{email: nil, first_name: nil, last_name: nil, user_id: nil, user_image: nil, roles: nil}

    setup do
      author = author_fixture()
      institution = institution_fixture(%{ author_id: author.id })
      {:ok, lti_tool_consumer} = Accounts.insert_or_update_lti_tool_consumer(%{
        info_product_family_code: "tool_consumer_info_product_family_code",
        info_version: "tool_consumer_info_version",
        instance_contact_email: "tool_consumer_instance_contact_email",
        instance_guid: "tool_consumer_instance_guid",
        instance_name: "tool_consumer_instance_name",
        institution_id: institution.id,
      })
      valid_attrs = @valid_attrs
        |> Map.put(:author_id, author.id)
        |> Map.put(:lti_tool_consumer_id, lti_tool_consumer.id)
      {:ok, user} = valid_attrs |> Accounts.create_user()

      {:ok, %{user: user, author: author, valid_attrs: valid_attrs}}
    end

    test "get_user!/1 returns the user with given id", %{user: user} do
      assert Accounts.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user", %{valid_attrs: valid_attrs} do
      assert {:ok, %User{} = user} = Accounts.create_user(valid_attrs)
      assert user.email == "some email"
      assert user.first_name == "some first_name"
      assert user.last_name == "some last_name"
      assert user.user_id == "some user_id"
      assert user.user_image == "some user_image"
      assert user.roles == "some roles"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user", %{user: user} do
      assert {:ok, %User{} = user} = Accounts.update_user(user, @update_attrs)
      assert user.email == "some updated email"
      assert user.first_name == "some updated first_name"
      assert user.last_name == "some updated last_name"
      assert user.user_id == "some updated user_id"
      assert user.user_image == "some updated user_image"
      assert user.roles == "some updated roles"
    end

    test "update_user/2 with invalid data returns error changeset", %{user: user} do
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "delete_user/1 deletes the user", %{user: user} do
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset", %{user: user} do
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end

  describe "institutions" do
    alias Oli.Accounts.Institution

    @valid_attrs %{country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", name: "some name", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret"}
    @update_attrs %{country_code: "some updated country_code", institution_email: "some updated institution_email", institution_url: "some updated institution_url", name: "some updated name", timezone: "some updated timezone"}
    @invalid_attrs %{country_code: nil, institution_email: nil, institution_url: nil, name: nil, timezone: nil}

    setup do
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: Accounts.SystemRole.role_id.author}) |> Repo.insert
      valid_attrs = Map.put(@valid_attrs, :author_id, author.id)
      {:ok, institution} = valid_attrs |> Accounts.create_institution()

      {:ok, %{institution: institution, author: author, valid_attrs: valid_attrs}}
    end

    test "list_institutions/0 returns all institutions", %{institution: institution} do
      assert Accounts.list_institutions() == [institution]
    end

    test "get_institution!/1 returns the institution with given id", %{institution: institution} do
      assert Accounts.get_institution!(institution.id) == institution
    end

    test "create_institution/1 with valid data creates a institution", %{valid_attrs: valid_attrs} do
      assert {:ok, %Institution{} = institution} = Accounts.create_institution(valid_attrs)
      assert institution.country_code == "some country_code"
      assert institution.institution_email == "some institution_email"
      assert institution.institution_url == "some institution_url"
      assert institution.name == "some name"
      assert institution.timezone == "some timezone"
    end

    test "create_institution/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_institution(@invalid_attrs)
    end

    test "update_institution/2 with valid data updates the institution", %{institution: institution} do
      assert {:ok, %Institution{} = institution} = Accounts.update_institution(institution, @update_attrs)
      assert institution.country_code == "some updated country_code"
      assert institution.institution_email == "some updated institution_email"
      assert institution.institution_url == "some updated institution_url"
      assert institution.name == "some updated name"
      assert institution.timezone == "some updated timezone"
    end

    test "update_institution/2 with invalid data returns error changeset", %{institution: institution} do
      assert {:error, %Ecto.Changeset{}} = Accounts.update_institution(institution, @invalid_attrs)
      assert institution == Accounts.get_institution!(institution.id)
    end

    test "delete_institution/1 deletes the institution", %{institution: institution} do
      assert {:ok, %Institution{}} = Accounts.delete_institution(institution)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_institution!(institution.id) end
    end

    test "change_institution/1 returns a institution changeset", %{institution: institution} do
      assert %Ecto.Changeset{} = Accounts.change_institution(institution)
    end
  end
end
