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

    test "catches hyphenated tokens like {first-name}" do
      assert Substitution.unsupported_tokens("Hi {first-name}") == ["{first-name}"]
    end

    test "catches digit-suffixed tokens like {first_name1}" do
      assert Substitution.unsupported_tokens("Hi {first_name1}") == ["{first_name1}"]
    end

    test "catches tokens with spaces like {First Name}" do
      assert Substitution.unsupported_tokens("Hi {First Name}") == ["{First Name}"]
    end

    test "catches tokens with leading whitespace like { first_name }" do
      assert Substitution.unsupported_tokens("Hi { first_name }") == ["{ first_name }"]
    end

    test "returns empty list when only whitelisted tokens appear" do
      assert Substitution.unsupported_tokens("{first_name} {course_name}") == []
    end

    test "returns empty list when no tokens appear" do
      assert Substitution.unsupported_tokens("Plain text") == []
    end

    test "returns empty list for empty braces `{}`" do
      assert Substitution.unsupported_tokens("Plain {} text") == []
    end

    test "deduplicates repeated unsupported tokens" do
      assert Substitution.unsupported_tokens("{foo} and {foo} and {bar}") |> Enum.sort() ==
               ~w({bar} {foo})
    end

    test "detects bare square-bracket placeholders like [Your Name]" do
      assert Substitution.unsupported_tokens("Best regards, [Your Name]") ==
               ["[Your Name]"]
    end

    test "detects multiple distinct bracket placeholders" do
      result =
        Substitution.unsupported_tokens(
          "Dear {first_name}, from [Your Name] re: [instructor's name]"
        )
        |> Enum.sort()

      assert result == ["[Your Name]", "[instructor's name]"]
    end

    test "skips markdown link labels — `[label](url)` is allowed" do
      assert Substitution.unsupported_tokens("See [the lesson](/sections/foo/bar) for details.") ==
               []
    end

    test "flags bare-bracket text but keeps markdown link labels in the same body" do
      body = "See [the lesson](/sections/foo) — signed, [Your Name]"
      assert Substitution.unsupported_tokens(body) == ["[Your Name]"]
    end

    test "reports both brace-typo and bracket placeholders together, deduped" do
      body = "Hi {firstName}, signed [Your Name] (also [Your Name])"

      result = Substitution.unsupported_tokens(body) |> Enum.sort()

      assert result == ["[Your Name]", "{firstName}"]
    end
  end

  describe "apply/2 — single-pass substitution (no re-processing of values)" do
    test "value containing a whitelisted token is inserted literally (not chain-substituted)" do
      # Hostile recipient: their given_name is literally "{course_name}".
      # A naive accumulating substitution would substitute first_name first,
      # then see "{course_name}" in the accumulator and replace it with the
      # real course name. Single-pass over the original template avoids this.
      adversarial_values = %{
        "first_name" => "{course_name}",
        "student_name" => "Alice Lee",
        "course_name" => "Calculus 101",
        "instructor_name" => "Dr. Sage"
      }

      assert Substitution.apply("Hi {first_name}", adversarial_values) ==
               {:ok, "Hi {course_name}"}
    end

    test "value containing multiple tokens is inserted as a literal string" do
      adversarial_values = %{
        "first_name" => "{first_name} {course_name}",
        "student_name" => "X",
        "course_name" => "Calc 101",
        "instructor_name" => "Dr"
      }

      assert Substitution.apply("Hi {first_name}!", adversarial_values) ==
               {:ok, "Hi {first_name} {course_name}!"}
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
