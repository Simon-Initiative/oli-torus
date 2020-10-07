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

    @valid_attrs %{email: "some email", first_name: "some first_name", last_name: "some last_name", user_id: "some user_id", user_image: "some user_image"}
    @update_attrs %{email: "some updated email", first_name: "some updated first_name", last_name: "some updated last_name", user_id: "some updated user_id", user_image: "some updated user_image"}
    @invalid_attrs %{email: nil, first_name: nil, last_name: nil, user_id: nil, user_image: nil}

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
      assert user.first_name == "some first_name"
      assert user.last_name == "some last_name"
      assert user.user_id == "some user_id"
      assert user.user_image == "some user_image"
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
