defmodule Oli.AccountsTest do
  use Oli.DataCase

  alias Oli.Accounts
  alias Oli.Accounts.User

  describe "institutions" do
    alias Oli.Accounts.Institution

    @valid_attrs %{country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", name: "some name", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", user_id: 1}
    @update_attrs %{country_code: "some updated country_code", institution_email: "some updated institution_email", institution_url: "some updated institution_url", name: "some updated name", timezone: "some updated timezone"}
    @invalid_attrs %{country_code: nil, institution_email: nil, institution_url: nil, name: nil, timezone: nil}

    setup do
      {:ok, user} = User.changeset(%User{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo"}) |> Repo.insert
      valid_attrs = Map.put(@valid_attrs, :user_id, user.id)
      {:ok, institution} = valid_attrs |> Accounts.create_institution()

      {:ok, %{institution: institution, user: user, valid_attrs: valid_attrs}}
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
