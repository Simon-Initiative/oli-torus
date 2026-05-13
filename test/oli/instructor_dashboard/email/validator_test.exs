defmodule Oli.InstructorDashboard.Email.ValidatorTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Email.{EmailContext, Validator}

  defp recipient(overrides \\ %{}) do
    Map.merge(
      %{
        student_id: 101,
        email: "alex@example.edu",
        given_name: "Alex",
        family_name: "Kim"
      },
      overrides
    )
  end

  defp context(recipients) do
    %EmailContext{
      section_id: 42,
      course_title: "Calculus 101",
      instructor_name: "Dr. Sage",
      scope_label: "Module 3",
      situation_key: :struggling_students,
      recipients: recipients,
      tone: :neutral,
      recipient_count: length(recipients)
    }
  end

  defp template(opts \\ []) do
    %{
      subject: Keyword.get(opts, :subject, "Update on {course_name}"),
      html_body: Keyword.get(opts, :html_body, "<p>Hi {first_name}</p>"),
      text_body: Keyword.get(opts, :text_body, "Hi {first_name}")
    }
  end

  describe "validate/2 — happy path" do
    test "returns :ok for a valid template + recipient" do
      assert :ok = Validator.validate(template(), context([recipient()]))
    end

    test "returns :ok for a template with no tokens" do
      tmpl = template(subject: "Plain", html_body: "<p>Plain</p>", text_body: "Plain")
      assert :ok = Validator.validate(tmpl, context([recipient()]))
    end
  end

  describe "validate/2 — recipients" do
    test "no_recipients when recipient list is empty" do
      ctx = %{context([recipient()]) | recipients: [], recipient_count: 0}

      assert {:error, errors} = Validator.validate(template(), ctx)
      assert :no_recipients in errors
    end
  end

  describe "validate/2 — invalid email" do
    test "flags recipient with a malformed email" do
      ctx = context([recipient(%{email: "not-an-email"})])

      assert {:error, errors} = Validator.validate(template(), ctx)
      assert {:invalid_email, "not-an-email"} in errors
    end

    test "flags multiple recipients with malformed emails" do
      ctx =
        context([
          recipient(%{email: "alex@example.edu"}),
          recipient(%{student_id: 2, email: "no-at-sign"}),
          recipient(%{student_id: 3, email: "missing-tld@x"})
        ])

      assert {:error, errors} = Validator.validate(template(), ctx)
      assert {:invalid_email, "no-at-sign"} in errors
      assert {:invalid_email, "missing-tld@x"} in errors
    end
  end

  describe "validate/2 — unsupported placeholders" do
    test "flags AI typo like {firstName}" do
      tmpl = template(subject: "Hi {firstName}")
      assert {:error, errors} = Validator.validate(tmpl, context([recipient()]))
      assert {:unsupported_placeholder, "{firstName}"} in errors
    end

    test "flags unknown token like {nickname}" do
      tmpl = template(text_body: "Hi {nickname}")
      assert {:error, errors} = Validator.validate(tmpl, context([recipient()]))
      assert {:unsupported_placeholder, "{nickname}"} in errors
    end

    test "deduplicates tokens that appear in multiple template fields" do
      tmpl =
        template(
          subject: "Hi {nickname}",
          html_body: "<p>{nickname}</p>",
          text_body: "{nickname}"
        )

      assert {:error, errors} = Validator.validate(tmpl, context([recipient()]))
      assert Enum.count(errors, &match?({:unsupported_placeholder, "{nickname}"}, &1)) == 1
    end
  end

  describe "validate/2 — unresolvable placeholders" do
    test "flags {first_name} when given_name missing for some recipients" do
      ctx =
        context([
          recipient(),
          recipient(%{student_id: 2, email: "b@x.edu", given_name: nil}),
          recipient(%{student_id: 3, email: "c@x.edu", given_name: ""})
        ])

      tmpl = template(subject: "Hi {first_name}", text_body: "Hi {first_name}")
      assert {:error, errors} = Validator.validate(tmpl, ctx)

      assert Enum.any?(errors, fn
               {:unresolvable_placeholder, "{first_name}", emails} ->
                 Enum.sort(emails) == ["b@x.edu", "c@x.edu"]

               _ ->
                 false
             end)
    end

    test "flags {student_name} when both name parts missing" do
      ctx = context([recipient(%{given_name: nil, family_name: nil})])
      tmpl = template(subject: "Hi {student_name}", text_body: "Hi {student_name}")

      assert {:error, errors} = Validator.validate(tmpl, ctx)

      assert Enum.any?(errors, fn
               {:unresolvable_placeholder, "{student_name}", _} -> true
               _ -> false
             end)
    end

    test "does NOT flag tokens that are NOT used in any template field" do
      ctx = context([recipient(%{given_name: nil})])

      tmpl =
        template(
          subject: "Static subject",
          html_body: "<p>Static html body</p>",
          text_body: "Static body"
        )

      assert :ok = Validator.validate(tmpl, ctx)
    end
  end

  describe "validate/2 — token appearing only in html_body is also checked" do
    test "flags {first_name} when present only in html_body" do
      ctx = context([recipient(%{given_name: nil})])

      tmpl =
        template(
          subject: "Static subject",
          text_body: "Static body",
          html_body: "<p>Hi {first_name}</p>"
        )

      assert {:error, errors} = Validator.validate(tmpl, ctx)

      assert Enum.any?(errors, fn
               {:unresolvable_placeholder, "{first_name}", _} -> true
               _ -> false
             end)
    end
  end

  describe "validate/2 — multiple reason types accumulate" do
    test "returns no_recipients + unsupported_placeholder together" do
      ctx = %{context([recipient()]) | recipients: [], recipient_count: 0}
      tmpl = template(subject: "Hi {nickname}")

      assert {:error, errors} = Validator.validate(tmpl, ctx)
      assert :no_recipients in errors
      assert {:unsupported_placeholder, "{nickname}"} in errors
    end
  end
end
