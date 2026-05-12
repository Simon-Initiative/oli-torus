defmodule Oli.InstructorDashboard.Email.SubstitutionTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Email.Substitution

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
      assert Substitution.apply("Hi {first_name}!", @complete_values) == "Hi Alice!"
    end

    test "substitutes multiple tokens in one string" do
      template = "Hi {first_name}, your {course_name} progress — {instructor_name}"

      assert Substitution.apply(template, @complete_values) ==
               "Hi Alice, your Calculus 101 progress — Dr. Sage"
    end

    test "substitutes repeated occurrences of the same token" do
      assert Substitution.apply("{first_name} {first_name} {first_name}", @complete_values) ==
               "Alice Alice Alice"
    end

    test "is a no-op when no tokens appear" do
      assert Substitution.apply("Plain text with no placeholders.", @complete_values) ==
               "Plain text with no placeholders."
    end
  end

  describe "apply/2 — unknown tokens pass through (validator's concern)" do
    test "non-whitelisted tokens are left unchanged" do
      assert Substitution.apply("Hi {firstName}", @complete_values) == "Hi {firstName}"
      assert Substitution.apply("Welcome {nickname}!", @complete_values) == "Welcome {nickname}!"
    end

    test "mixed whitelisted + non-whitelisted: only whitelisted replaced" do
      assert Substitution.apply("{first_name} is in {nickname}", @complete_values) ==
               "Alice is in {nickname}"
    end
  end

  describe "apply/2 — defensive: raises on nil value" do
    test "raises ArgumentError when a whitelist token has a nil value AND appears in the string" do
      bad_values = Map.put(@complete_values, "first_name", nil)

      assert_raise ArgumentError, ~r/nil value for token \{first_name\}/, fn ->
        Substitution.apply("Hi {first_name}", bad_values)
      end
    end

    test "raises even if the nil-valued token does not appear in the string" do
      # Defensive: we reduce over the whole whitelist, so a nil anywhere is a programming error.
      bad_values = Map.put(@complete_values, "first_name", nil)

      assert_raise ArgumentError, ~r/nil value for token/, fn ->
        Substitution.apply("Plain string", bad_values)
      end
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
