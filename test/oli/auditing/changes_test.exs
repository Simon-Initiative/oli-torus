defmodule Oli.Auditing.ChangesTest do
  use ExUnit.Case, async: true

  alias Oli.Auditing.{Changes, Sensitive}

  doctest Changes

  @spec_fields %{max_attempts: :value, end_date: :value, password: :secret}

  describe "diff/3" do
    test "records only changed fields and redacts secret fields" do
      before = %{max_attempts: 1, end_date: nil, password: "old-secret", title: "ignored"}
      after_state = %{max_attempts: 3, end_date: nil, password: "new-secret", title: "changed"}

      changes = Changes.diff(before, after_state, @spec_fields)

      assert changes == %{
               "max_attempts" => %{"operation" => "set", "before" => 1, "after" => 3},
               "password" => Changes.secret_record()
             }

      refute inspect(changes) =~ "secret\""
      refute inspect(changes) =~ "new-secret"
    end

    test "distinguishes an explicit null from a missing side" do
      assert Changes.diff(%{end_date: "2026-11-01"}, %{end_date: nil}, %{end_date: :value}) ==
               %{"end_date" => %{"operation" => "set", "before" => "2026-11-01", "after" => nil}}

      assert Changes.diff(nil, %{max_attempts: 2}, %{max_attempts: :value}) ==
               %{"max_attempts" => %{"operation" => "set", "after" => 2}}

      assert Changes.diff(%{max_attempts: 2}, nil, %{max_attempts: :value}) ==
               %{"max_attempts" => %{"operation" => "set", "before" => 2}}
    end

    test "omits a side whose field is missing from a persisted map" do
      assert Changes.diff(%{}, %{max_attempts: 1}, %{max_attempts: :value}) ==
               %{"max_attempts" => %{"operation" => "set", "after" => 1}}
    end

    test "normalizes dates, decimals, atoms, and embedded schemas to JSON-native values" do
      changes =
        Changes.diff(
          %{end_date: ~U[2026-11-01 23:59:00Z], amount: Decimal.new("25.00"), mode: :traditional},
          %{
            end_date: ~U[2026-11-02 23:59:00Z],
            amount: Decimal.new("30.00"),
            mode: :one_at_a_time
          },
          %{end_date: :value, amount: :value, mode: :value}
        )

      assert changes["end_date"]["after"] == "2026-11-02T23:59:00Z"
      assert changes["amount"]["after"] == "30.00"
      assert changes["mode"]["before"] == "traditional"
      assert :ok = Changes.validate(changes, %{end_date: :value, amount: :value, mode: :value})
    end

    test "returns no changes when persisted state is unchanged" do
      assert Changes.diff(%{max_attempts: 2}, %{max_attempts: 2}, @spec_fields) == %{}
    end

    test "treats decimals with different scales as unchanged" do
      assert Changes.diff(%{amount: Decimal.new("1.0")}, %{amount: Decimal.new("1.00")}, %{
               amount: :value
             }) == %{}
    end

    test "keeps map values with non-string keys encodable" do
      assert %{"options" => %{"after" => %{"{1}" => 2}}} =
               Changes.diff(%{options: %{}}, %{options: %{{1} => 2}}, %{options: :value})
    end
  end

  describe "validate/2" do
    test "accepts value records, reset records, and secret markers" do
      assert :ok =
               Changes.validate(
                 %{
                   "max_attempts" => %{
                     "operation" => "reset",
                     "before" => 3,
                     "after" => nil,
                     "effective_before" => 3,
                     "effective_after" => 1,
                     "result_source" => "publication"
                   },
                   "password" => Changes.secret_record()
                 },
                 @spec_fields
               )
    end

    test "rejects unknown fields, record keys, and operations" do
      assert {:error, "unknown change field title"} =
               Changes.validate(%{"title" => %{"operation" => "set"}}, @spec_fields)

      assert {:error, _} =
               Changes.validate(
                 %{"max_attempts" => %{"operation" => "set", "old" => 1}},
                 @spec_fields
               )

      assert {:error, _} =
               Changes.validate(%{"max_attempts" => %{"operation" => "replace"}}, @spec_fields)

      assert {:error, _} = Changes.validate(%{"max_attempts" => 3}, @spec_fields)
      assert {:error, _} = Changes.validate([], @spec_fields)
    end

    test "secret fields reject the redaction marker with extra keys" do
      marker = "marker-#{System.unique_integer([:positive])}"

      for extra <- ["before", "after"] do
        record = Map.put(Changes.secret_record(), extra, marker)
        assert {:error, message} = Changes.validate(%{"password" => record}, @spec_fields)
        refute message =~ marker
      end
    end

    test "rejects structs, non-string field names, and non-string map keys" do
      assert {:error, _} =
               Changes.validate(
                 %{"end_date" => %{"operation" => "set", "after" => ~U[2026-11-01 00:00:00Z]}},
                 @spec_fields
               )

      assert {:error, "change fields must be strings"} =
               Changes.validate(%{{:bad} => %{"operation" => "set"}}, @spec_fields)

      assert {:error, _} =
               Changes.validate(
                 %{"end_date" => %{"operation" => "set", "after" => %{{:k} => 1}}},
                 @spec_fields
               )

      assert {:error, "changes must be a map"} = Changes.validate(~D[2026-01-01], @spec_fields)
    end

    test "rejects improper lists, invalid UTF-8, and set records without values" do
      for value <- [[1 | 2], <<0xFF, 0xFE>>] do
        assert {:error, _} =
                 Changes.validate(
                   %{"max_attempts" => %{"operation" => "set", "after" => value}},
                   @spec_fields
                 )
      end

      assert {:error, "change field max_attempts needs a before or after value"} =
               Changes.validate(%{"max_attempts" => %{"operation" => "set"}}, @spec_fields)
    end

    test "secret fields accept only the redaction marker" do
      assert {:error, message} =
               Changes.validate(
                 %{"password" => %{"operation" => "set", "after" => "x"}},
                 @spec_fields
               )

      assert message =~ "password"
    end

    test "non-secret fields cannot be redacted or contain nested secret keys" do
      assert {:error, _} =
               Changes.validate(%{"max_attempts" => Changes.secret_record()}, @spec_fields)

      assert {:error, _} =
               Changes.validate(
                 %{
                   "end_date" => %{
                     "operation" => "set",
                     "after" => %{"nested" => %{"api_key" => "k"}}
                   }
                 },
                 @spec_fields
               )
    end
  end

  describe "Sensitive" do
    test "detects secret-looking key names at any depth" do
      assert Sensitive.key?("Password_Hash")
      assert Sensitive.key?(:api_key)

      for key <- ~w(passcode passphrase client_key access_key jwks bearer_value user_otp) do
        assert Sensitive.key?(key), key
      end

      refute Sensitive.key?("footprint")
      refute Sensitive.key?("key_set_url")
      refute Sensitive.key?("max_attempts")

      assert Sensitive.find_key(%{"a" => [%{"b" => %{"session_cookie" => 1}}]}) == [
               "a",
               "b",
               "session_cookie"
             ]

      assert Sensitive.find_key(%{"a" => 1}) == nil
    end
  end
end
