defmodule Oli.Lti_1p3.NoncesTest do
  use Oli.DataCase

  alias Oli.Repo
  alias Oli.Lti_1p3.Nonce
  alias Oli.Lti_1p3.Nonces

  describe "lti 1.3 nonces" do
    test "should get existing nonce" do
      {:ok, nonce} = %Nonce{}
      |> Nonce.changeset(%{value: "some-value", domain: "some-domain"})
      |> Repo.insert()

      assert Nonces.get_nonce!(nonce.id).value == "some-value"
      assert Nonces.get_nonce!(nonce.id).domain == "some-domain"
    end

    test "should create new nonce with default domain nil" do
      {:ok, nonce} = Nonces.create_nonce("some-value")

      assert nonce.value == "some-value"
      assert nonce.domain == nil
    end

    test "should create new nonce with specified domain" do
      {:ok, nonce} = Nonces.create_nonce("some-value", "some-domain")

      assert nonce.value == "some-value"
      assert nonce.domain == "some-domain"
    end

    test "should create new nonce with specified domain if one already exists with different domain" do
      {:ok, _nonce1} = Nonces.create_nonce("some-value")
      {:ok, _nonce2} = Nonces.create_nonce("some-value", "some-domain")
      {:ok, nonce3} = Nonces.create_nonce("some-value", "different-domain")

      assert nonce3.value == "some-value"
      assert nonce3.domain == "different-domain"
    end

    test "should fail to create new nonce if one already exists with specified domain" do
      {:ok, _nonce} = Nonces.create_nonce("some-value", "some-domain")

      assert {:error, %Ecto.Changeset{}} = Nonces.create_nonce("some-value", "some-domain")
    end

    test "should cleanup expired nonces" do
      {:ok, nonce} = Nonces.create_nonce("some-value")

      # verify the nonce exists before cleanup
      assert Nonces.get_nonce!(nonce.id) == nonce

      # fake the nonce was created a day + 1 hour ago
      a_day_before = Timex.now |> Timex.subtract(Timex.Duration.from_hours(25))
      nonce
      |> Ecto.Changeset.cast(%{inserted_at: a_day_before}, [:inserted_at])
      |> Repo.update!

      # cleanup
      Nonces.cleanup_nonce_store()

      assert_raise Ecto.NoResultsError, ~r/^expected at least one result but got none in query/, fn ->
        # no more nonce
        Nonces.get_nonce!(nonce.id)
      end
    end
  end

end
