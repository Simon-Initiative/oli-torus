defmodule Oli.Lti_1p3.NoncesTest do
  use Oli.DataCase

  alias Oli.Repo
  alias Oli.Lti_1p3.Nonce
  alias Oli.Lti_1p3.Nonces

  describe "lti 1.3 nonces" do
    test "should get existing nonce" do
      {:ok, nonce} = %Nonce{}
      |> Nonce.changeset(%{value: "some-value"})
      |> Repo.insert()

      assert Nonces.get_nonce!(nonce.id).value == "some-value"
    end

    test "should create new nonce" do
      {:ok, nonce} = Nonces.create_nonce(%{value: "some-value"})

      assert nonce.value == "some-value"
    end

    test "should cleanup expired nonces" do
      {:ok, nonce} = Nonces.create_nonce(%{value: "some-value"})

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
