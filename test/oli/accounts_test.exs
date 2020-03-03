defmodule Oli.AccountsTest do
  use Oli.DataCase

  alias Oli.Accounts

  describe "institutions" do
    alias Oli.Accounts.Institution

    @valid_attrs %{country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", name: "some name", timezone: "some timezone"}
    @update_attrs %{country_code: "some updated country_code", institution_email: "some updated institution_email", institution_url: "some updated institution_url", name: "some updated name", timezone: "some updated timezone"}
    @invalid_attrs %{country_code: nil, institution_email: nil, institution_url: nil, name: nil, timezone: nil}

    def institution_fixture(attrs \\ %{}) do
      {:ok, institution} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Accounts.create_institution()

      institution
    end

    test "list_institutions/0 returns all institutions" do
      institution = institution_fixture()
      assert Accounts.list_institutions() == [institution]
    end

    test "get_institution!/1 returns the institution with given id" do
      institution = institution_fixture()
      assert Accounts.get_institution!(institution.id) == institution
    end

    test "create_institution/1 with valid data creates a institution" do
      assert {:ok, %Institution{} = institution} = Accounts.create_institution(@valid_attrs)
      assert institution.country_code == "some country_code"
      assert institution.institution_email == "some institution_email"
      assert institution.institution_url == "some institution_url"
      assert institution.name == "some name"
      assert institution.timezone == "some timezone"
    end

    test "create_institution/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_institution(@invalid_attrs)
    end

    test "update_institution/2 with valid data updates the institution" do
      institution = institution_fixture()
      assert {:ok, %Institution{} = institution} = Accounts.update_institution(institution, @update_attrs)
      assert institution.country_code == "some updated country_code"
      assert institution.institution_email == "some updated institution_email"
      assert institution.institution_url == "some updated institution_url"
      assert institution.name == "some updated name"
      assert institution.timezone == "some updated timezone"
    end

    test "update_institution/2 with invalid data returns error changeset" do
      institution = institution_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_institution(institution, @invalid_attrs)
      assert institution == Accounts.get_institution!(institution.id)
    end

    test "delete_institution/1 deletes the institution" do
      institution = institution_fixture()
      assert {:ok, %Institution{}} = Accounts.delete_institution(institution)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_institution!(institution.id) end
    end

    test "change_institution/1 returns a institution changeset" do
      institution = institution_fixture()
      assert %Ecto.Changeset{} = Accounts.change_institution(institution)
    end
  end
end
