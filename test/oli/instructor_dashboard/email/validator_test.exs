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
      text_body: Keyword.get(opts, :text_body, "Hi {first_name}"),
      body_slate: Keyword.get(opts, :body_slate, [])
    }
  end

  defp slate_with_link(href) do
    [
      %{
        "type" => "p",
        "children" => [
          %{"type" => "a", "href" => href, "children" => [%{"text" => "x"}]}
        ]
      }
    ]
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

  describe "validate/2 — duplicate recipients" do
    test "flags {:duplicate_recipients, ids} when a student_id appears more than once" do
      r1 = recipient(%{student_id: 101, email: "alex@x.edu"})
      r2 = recipient(%{student_id: 202, email: "bo@x.edu"})
      dup = recipient(%{student_id: 101, email: "alex@x.edu"})

      ctx = context([r1, r2, dup])

      assert {:error, errors} = Validator.validate(template(), ctx)

      assert Enum.any?(errors, fn
               {:duplicate_recipients, [101]} -> true
               _ -> false
             end)
    end

    test "reports all duplicate student_ids when multiple are duped" do
      ctx =
        context([
          recipient(%{student_id: 1, email: "a@x.edu"}),
          recipient(%{student_id: 1, email: "a@x.edu"}),
          recipient(%{student_id: 2, email: "b@x.edu"}),
          recipient(%{student_id: 2, email: "b@x.edu"})
        ])

      assert {:error, errors} = Validator.validate(template(), ctx)

      assert Enum.any?(errors, fn
               {:duplicate_recipients, ids} -> Enum.sort(ids) == [1, 2]
               _ -> false
             end)
    end

    test "accepts when every student_id is unique" do
      ctx =
        context([
          recipient(%{student_id: 1, email: "a@x.edu"}),
          recipient(%{student_id: 2, email: "b@x.edu"}),
          recipient(%{student_id: 3, email: "c@x.edu"})
        ])

      assert :ok = Validator.validate(template(), ctx)
    end
  end

  describe "validate/2 — whitespace-only recipient name fields treated as nil" do
    test "flags {first_name} as unresolvable when given_name is whitespace-only" do
      ctx = context([recipient(%{given_name: "   "})])

      tmpl = template(subject: "Hi {first_name}", text_body: "Hi {first_name}")

      assert {:error, errors} = Validator.validate(tmpl, ctx)

      assert Enum.any?(errors, fn
               {:unresolvable_placeholder, "{first_name}", _} -> true
               _ -> false
             end)
    end

    test "flags {student_name} as unresolvable when both name fields are whitespace" do
      ctx = context([recipient(%{given_name: "  ", family_name: "\t"})])

      tmpl = template(subject: "Hi {student_name}", text_body: "Hi {student_name}")

      assert {:error, errors} = Validator.validate(tmpl, ctx)

      assert Enum.any?(errors, fn
               {:unresolvable_placeholder, "{student_name}", _} -> true
               _ -> false
             end)
    end
  end

  describe "validate/2 — instructor_email validation" do
    test "accepts nil instructor_email (optional reply_to)" do
      ctx = %{context([recipient()]) | instructor_email: nil}
      assert :ok = Validator.validate(template(), ctx)
    end

    test "accepts empty-string instructor_email" do
      ctx = %{context([recipient()]) | instructor_email: ""}
      assert :ok = Validator.validate(template(), ctx)
    end

    test "flags malformed instructor_email as {:invalid_instructor_email, addr}" do
      ctx = %{context([recipient()]) | instructor_email: "not-an-email"}

      assert {:error, errors} = Validator.validate(template(), ctx)
      assert {:invalid_instructor_email, "not-an-email"} in errors
    end

    test "accepts well-formed instructor_email" do
      ctx = %{context([recipient()]) | instructor_email: "sage@example.edu"}
      assert :ok = Validator.validate(template(), ctx)
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

  describe "validate/2 — unsafe links (tree walk on body_slate)" do
    test "flags external https link" do
      tmpl = template(body_slate: slate_with_link("https://evil.com/phish"))

      assert {:error, errors} = Validator.validate(tmpl, context([recipient()]))
      assert {:unsafe_link, "https://evil.com/phish"} in errors
    end

    test "flags javascript scheme link" do
      tmpl = template(body_slate: slate_with_link("javascript:xss"))

      assert {:error, errors} = Validator.validate(tmpl, context([recipient()]))
      assert {:unsafe_link, "javascript:xss"} in errors
    end

    test "flags mailto link" do
      tmpl = template(body_slate: slate_with_link("mailto:x@y.com"))

      assert {:error, errors} = Validator.validate(tmpl, context([recipient()]))
      assert {:unsafe_link, "mailto:x@y.com"} in errors
    end

    test "flags protocol-relative link" do
      tmpl = template(body_slate: slate_with_link("//evil.com/path"))

      assert {:error, errors} = Validator.validate(tmpl, context([recipient()]))
      assert {:unsafe_link, "//evil.com/path"} in errors
    end

    test "flags path traversal segment" do
      tmpl = template(body_slate: slate_with_link("/foo/../admin"))

      assert {:error, errors} = Validator.validate(tmpl, context([recipient()]))
      assert {:unsafe_link, "/foo/../admin"} in errors
    end

    test "flags relative path that does not resolve to a route" do
      tmpl = template(body_slate: slate_with_link("/totally/fake/path"))

      assert {:error, errors} = Validator.validate(tmpl, context([recipient()]))
      assert {:unsafe_link, "/totally/fake/path"} in errors
    end

    test "accepts valid internal relative path that resolves to a route" do
      tmpl = template(body_slate: slate_with_link("/unauthorized"))

      assert :ok = Validator.validate(tmpl, context([recipient()]))
    end

    test "accepts body_slate with no links" do
      tmpl =
        template(body_slate: [%{"type" => "p", "children" => [%{"text" => "plain body"}]}])

      assert :ok = Validator.validate(tmpl, context([recipient()]))
    end

    test "deduplicates the same unsafe URL appearing twice" do
      tmpl =
        template(
          body_slate: [
            %{
              "type" => "p",
              "children" => [
                %{"type" => "a", "href" => "https://evil.com", "children" => [%{"text" => "a"}]},
                %{"type" => "a", "href" => "https://evil.com", "children" => [%{"text" => "b"}]}
              ]
            }
          ]
        )

      assert {:error, errors} = Validator.validate(tmpl, context([recipient()]))
      assert Enum.count(errors, &match?({:unsafe_link, "https://evil.com"}, &1)) == 1
    end

    test "accumulates multiple distinct unsafe URLs" do
      tmpl =
        template(
          body_slate: [
            %{
              "type" => "p",
              "children" => [
                %{"type" => "a", "href" => "https://evil.com", "children" => [%{"text" => "a"}]},
                %{"type" => "a", "href" => "javascript:x", "children" => [%{"text" => "b"}]}
              ]
            }
          ]
        )

      assert {:error, errors} = Validator.validate(tmpl, context([recipient()]))
      assert {:unsafe_link, "https://evil.com"} in errors
      assert {:unsafe_link, "javascript:x"} in errors
    end
  end

  describe "validate/2 — unsafe bare URLs in text_body" do
    test "flags bare URL in rendered text_body" do
      tmpl = template(text_body: "Hi Alex, visit https://evil.com for help.")

      assert {:error, errors} = Validator.validate(tmpl, context([recipient()]))
      assert {:unsafe_link, "https://evil.com"} in errors
    end

    test "deduplicates same bare URL appearing twice" do
      tmpl =
        template(text_body: "See https://evil.com or https://evil.com")

      assert {:error, errors} = Validator.validate(tmpl, context([recipient()]))
      assert Enum.count(errors, &match?({:unsafe_link, "https://evil.com"}, &1)) == 1
    end

    test "accepts text_body with no URLs" do
      tmpl = template(text_body: "Hi Alex, your progress is steady.")

      assert :ok = Validator.validate(tmpl, context([recipient()]))
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
