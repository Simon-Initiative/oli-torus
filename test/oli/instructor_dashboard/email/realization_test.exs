defmodule Oli.InstructorDashboard.Email.RealizationTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Email.{EmailContext, Realization}

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
      html_body:
        Keyword.get(opts, :html_body, "<p>Hi {first_name}, sincerely {instructor_name}</p>"),
      text_body: Keyword.get(opts, :text_body, "Hi {first_name}, sincerely {instructor_name}")
    }
  end

  describe "values_for/2" do
    test "maps tokens to their EmailContext + recipient sources" do
      ctx = context([recipient()])
      [r] = ctx.recipients

      assert Realization.values_for(r, ctx) == %{
               "first_name" => "Alex",
               "student_name" => "Alex Kim",
               "course_name" => "Calculus 101",
               "instructor_name" => "Dr. Sage"
             }
    end

    test "student_name falls back to given_name only when family_name is nil" do
      ctx = context([recipient(%{family_name: nil})])
      [r] = ctx.recipients

      assert %{"student_name" => "Alex"} = Realization.values_for(r, ctx)
    end

    test "student_name falls back to given_name only when family_name is empty" do
      ctx = context([recipient(%{family_name: ""})])
      [r] = ctx.recipients

      assert %{"student_name" => "Alex"} = Realization.values_for(r, ctx)
    end

    test "first_name returns nil when given_name is empty" do
      ctx = context([recipient(%{given_name: ""})])
      [r] = ctx.recipients

      assert %{"first_name" => nil} = Realization.values_for(r, ctx)
    end

    test "student_name returns nil when given_name is nil" do
      ctx = context([recipient(%{given_name: nil, family_name: "Smith"})])
      [r] = ctx.recipients

      assert %{"student_name" => nil} = Realization.values_for(r, ctx)
    end
  end

  describe "realize/2 — happy path" do
    test "substitutes per recipient and preserves user_id + email" do
      ctx =
        context([
          recipient(),
          recipient(%{
            student_id: 202,
            email: "bo@example.edu",
            given_name: "Bo",
            family_name: "Lin"
          })
        ])

      assert {:ok, [r1, r2]} = Realization.realize(template(), ctx)

      assert r1.user_id == 101
      assert r1.email == "alex@example.edu"
      assert r1.subject == "Update on Calculus 101"
      assert r1.html_body == "<p>Hi Alex, sincerely Dr. Sage</p>"
      assert r1.text_body == "Hi Alex, sincerely Dr. Sage"

      assert r2.user_id == 202
      assert r2.email == "bo@example.edu"
      assert r2.html_body == "<p>Hi Bo, sincerely Dr. Sage</p>"
    end

    test "returns one entry per recipient (preserves order + count)" do
      recipients = for i <- 1..5, do: recipient(%{student_id: i, email: "u#{i}@x.edu"})
      ctx = context(recipients)

      assert {:ok, result} = Realization.realize(template(), ctx)

      assert length(result) == 5
      assert Enum.map(result, & &1.user_id) == [1, 2, 3, 4, 5]
    end

    test "no tokens in template -> identical output for every recipient" do
      ctx =
        context([
          recipient(),
          recipient(%{student_id: 202, email: "bo@example.edu", given_name: "Bo"})
        ])

      tmpl = template(subject: "Static", html_body: "<p>Static</p>", text_body: "Static")
      assert {:ok, [r1, r2]} = Realization.realize(tmpl, ctx)

      assert r1.subject == "Static"
      assert r1.html_body == "<p>Static</p>"
      assert r2.subject == "Static"
    end
  end

  describe "realize/2 — structured errors" do
    test "returns {:error, [{:realize_failed, email, token}, ...]} for a nil value" do
      ctx = context([recipient(%{given_name: nil})])
      tmpl = template(subject: "Hi {first_name}", text_body: "Hi {first_name}")

      assert {:error, reasons} = Realization.realize(tmpl, ctx)
      assert {:realize_failed, "alex@example.edu", "{first_name}"} in reasons
    end

    test "accumulates errors across multiple recipients" do
      ctx =
        context([
          recipient(%{given_name: nil, email: "alice@x.edu"}),
          recipient(%{student_id: 202, given_name: nil, email: "bo@x.edu"})
        ])

      tmpl = template(subject: "Hi {first_name}", text_body: "Hi {first_name}")

      assert {:error, reasons} = Realization.realize(tmpl, ctx)

      emails_in_reasons =
        Enum.map(reasons, fn {:realize_failed, email, _} -> email end)
        |> Enum.sort()

      assert emails_in_reasons == ["alice@x.edu", "bo@x.edu"]
    end

    test "succeeds for static templates even when recipients have nil names" do
      ctx = context([recipient(%{given_name: nil})])
      tmpl = template(subject: "Static", html_body: "<p>Static</p>", text_body: "Static")

      assert {:ok, [r]} = Realization.realize(tmpl, ctx)
      assert r.subject == "Static"
    end
  end

  describe "realize/2 — HTML-escapes recipient values in html_body" do
    test "given_name containing HTML metacharacters is escaped in html_body but raw in text/subject" do
      ctx = context([recipient(%{given_name: "<script>alert(1)</script>", family_name: "Kim"})])

      tmpl =
        template(
          subject: "Hi {first_name}",
          html_body: "<p>Hi {first_name}</p>",
          text_body: "Hi {first_name}"
        )

      assert {:ok, [r]} = Realization.realize(tmpl, ctx)

      assert r.html_body == "<p>Hi &lt;script&gt;alert(1)&lt;/script&gt;</p>"
      assert r.subject == "Hi <script>alert(1)</script>"
      assert r.text_body == "Hi <script>alert(1)</script>"
    end

    test "ampersand and quotes in given_name are escaped in html_body" do
      ctx = context([recipient(%{given_name: "A&B \"Quote\""})])
      tmpl = template(html_body: "<p>Hi {first_name}</p>", subject: "S", text_body: "T")

      assert {:ok, [r]} = Realization.realize(tmpl, ctx)
      assert r.html_body == "<p>Hi A&amp;B &quot;Quote&quot;</p>"
    end
  end
end
