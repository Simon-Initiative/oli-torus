defmodule Oli.InstructorDashboard.Email.SubstitutionTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Email.Substitution

  doctest Substitution

  @complete_values %{
    "first_name" => "Alice",
    "student_name" => "Alice Lee",
    "course_name" => "Calculus 101",
    "instructor_name" => "Dr. Sage"
  }

  describe "whitelist/0 + tokens/0" do
    test "matches PromptComposer whitelist of 4 tokens" do
      assert Substitution.whitelist() == ~w(first_name student_name instructor_name course_name)
    end

    test "tokens are the whitelist names wrapped in braces" do
      assert Substitution.tokens() ==
               ~w({first_name} {student_name} {instructor_name} {course_name})
    end
  end

  describe "apply/2 — known token replacement" do
    test "substitutes a single token" do
      assert Substitution.apply("Hi {first_name}!", @complete_values) == {:ok, "Hi Alice!"}
    end

    test "substitutes multiple tokens in one string" do
      template = "Hi {first_name}, your {course_name} progress — {instructor_name}"

      assert Substitution.apply(template, @complete_values) ==
               {:ok, "Hi Alice, your Calculus 101 progress — Dr. Sage"}
    end

    test "substitutes repeated occurrences of the same token" do
      assert Substitution.apply("{first_name} {first_name} {first_name}", @complete_values) ==
               {:ok, "Alice Alice Alice"}
    end

    test "is a no-op when no tokens appear" do
      assert Substitution.apply("Plain text with no placeholders.", @complete_values) ==
               {:ok, "Plain text with no placeholders."}
    end
  end

  describe "apply/2 — unknown tokens pass through (validator's concern)" do
    test "non-whitelisted tokens are left unchanged" do
      assert Substitution.apply("Hi {firstName}", @complete_values) == {:ok, "Hi {firstName}"}

      assert Substitution.apply("Welcome {nickname}!", @complete_values) ==
               {:ok, "Welcome {nickname}!"}
    end

    test "mixed whitelisted + non-whitelisted: only whitelisted replaced" do
      assert Substitution.apply("{first_name} is in {nickname}", @complete_values) ==
               {:ok, "Alice is in {nickname}"}
    end
  end

  describe "apply/2 — structured errors on nil values" do
    test "returns {:error, [{:nil_value, token}]} when a whitelist token has nil value AND appears in the string" do
      bad_values = Map.put(@complete_values, "first_name", nil)

      assert Substitution.apply("Hi {first_name}", bad_values) ==
               {:error, [{:nil_value, "{first_name}"}]}
    end

    test "accumulates errors from multiple nil-valued tokens used in the same string" do
      bad_values =
        @complete_values
        |> Map.put("first_name", nil)
        |> Map.put("student_name", nil)

      assert {:error, errors} =
               Substitution.apply("Hi {first_name} aka {student_name}", bad_values)

      assert Enum.sort(errors) == [{:nil_value, "{first_name}"}, {:nil_value, "{student_name}"}]
    end

    test "is a no-op when the nil-valued token does not appear in the string" do
      bad_values = Map.put(@complete_values, "first_name", nil)

      assert Substitution.apply("Plain string with no placeholders", bad_values) ==
               {:ok, "Plain string with no placeholders"}
    end

    test "does not surface errors for unused tokens even when several have nil values" do
      bad_values =
        @complete_values
        |> Map.put("first_name", nil)
        |> Map.put("student_name", nil)

      assert Substitution.apply("Hello {course_name}", bad_values) ==
               {:ok, "Hello Calculus 101"}
    end
  end

  describe "unsupported_tokens/1" do
    test "returns tokens present but not in whitelist (including camelCase AI typos)" do
      assert Substitution.unsupported_tokens("Hi {firstName} and {nickname}") |> Enum.sort() ==
               ~w({firstName} {nickname}) |> Enum.sort()
    end

    test "returns empty list when only whitelisted tokens appear" do
      assert Substitution.unsupported_tokens("{first_name} {course_name}") == []
    end

    test "returns empty list when no tokens appear" do
      assert Substitution.unsupported_tokens("Plain text") == []
    end

    test "deduplicates repeated unsupported tokens" do
      assert Substitution.unsupported_tokens("{foo} and {foo} and {bar}") |> Enum.sort() ==
               ~w({bar} {foo})
    end
  end

  describe "used_tokens/1" do
    test "returns only whitelisted tokens that appear in the string" do
      assert Substitution.used_tokens("Hi {first_name}, in {course_name}") |> Enum.sort() ==
               ~w({course_name} {first_name})
    end

    test "ignores non-whitelisted tokens" do
      assert Substitution.used_tokens("{nickname} {first_name}") == ["{first_name}"]
    end

    test "returns empty list when no whitelisted tokens appear" do
      assert Substitution.used_tokens("Plain text") == []
    end
  end
end
