defmodule Oli.LtiTest do
  use Oli.DataCase

  alias Oli.Delivery.Lti

  describe "parse_lti_role" do
    test "handles student role" do
      assert Lti.parse_lti_role("Learner") == :student
    end

    test "handles instructor role" do
      assert Lti.parse_lti_role("Instructor") == :instructor
    end

    test "handles administrator role" do
      assert Lti.parse_lti_role("Instructor,urn:lti:instrole:ims/lis/Administrator") == :administrator
    end
  end

  describe "nonce_store" do
    alias Oli.Delivery.Lti.Nonce

    @valid_attrs %{value: "some value"}
    @update_attrs %{value: "some updated value"}
    @invalid_attrs %{value: nil}

    def nonce_fixture(attrs \\ %{}) do
      {:ok, nonce} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Lti.create_nonce()

      nonce
    end

    test "list_nonce_store/0 returns all nonce_store" do
      nonce = nonce_fixture()
      assert Lti.list_nonce_store() == [nonce]
    end

    test "get_nonce!/1 returns the nonce with given id" do
      nonce = nonce_fixture()
      assert Lti.get_nonce!(nonce.id) == nonce
    end

    test "create_nonce/1 with valid data creates a nonce" do
      assert {:ok, %Nonce{} = nonce} = Lti.create_nonce(@valid_attrs)
      assert nonce.value == "some value"
    end

    test "create_nonce/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Lti.create_nonce(@invalid_attrs)
    end

    test "update_nonce/2 with valid data updates the nonce" do
      nonce = nonce_fixture()
      assert {:ok, %Nonce{} = nonce} = Lti.update_nonce(nonce, @update_attrs)
      assert nonce.value == "some updated value"
    end

    test "update_nonce/2 with invalid data returns error changeset" do
      nonce = nonce_fixture()
      assert {:error, %Ecto.Changeset{}} = Lti.update_nonce(nonce, @invalid_attrs)
      assert nonce == Lti.get_nonce!(nonce.id)
    end

    test "delete_nonce/1 deletes the nonce" do
      nonce = nonce_fixture()
      assert {:ok, %Nonce{}} = Lti.delete_nonce(nonce)
      assert_raise Ecto.NoResultsError, fn -> Lti.get_nonce!(nonce.id) end
    end

    test "change_nonce/1 returns a nonce changeset" do
      nonce = nonce_fixture()
      assert %Ecto.Changeset{} = Lti.change_nonce(nonce)
    end
  end
end
