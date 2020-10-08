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

    @valid_attrs %{email: "some email", given_name: "some given_name", family_name: "some family_name", sub: "some sub", picture: "some picture"}
    @update_attrs %{email: "some updated email", given_name: "some updated given_name", family_name: "some updated family_name", sub: "some updated sub", picture: "some updated picture"}
    @invalid_attrs %{email: nil, given_name: nil, family_name: nil, sub: nil, picture: nil}

    setup do
      author = author_fixture()
      valid_attrs = @valid_attrs
        |> Map.put(:author_id, author.id)
      {:ok, user} = valid_attrs |> Accounts.create_user()

      {:ok, %{user: user, author: author, valid_attrs: valid_attrs}}
    end

    test "get_user!/1 returns the user with given id", %{user: user} do
      assert Accounts.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user", %{valid_attrs: valid_attrs} do
      assert {:ok, %User{} = user} = Accounts.create_user(valid_attrs)
      assert user.email == "some email"
      assert user.given_name == "some given_name"
      assert user.family_name == "some family_name"
      assert user.sub == "some sub"
      assert user.picture == "some picture"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user", %{user: user} do
      assert {:ok, %User{} = user} = Accounts.update_user(user, @update_attrs)
      assert user.email == "some updated email"
      assert user.given_name == "some updated given_name"
      assert user.family_name == "some updated family_name"
      assert user.sub == "some updated sub"
      assert user.picture == "some updated picture"
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

end
