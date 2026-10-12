defmodule OliWeb.ManualGrading.ScoringLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Activities.Model.Part
  alias Oli.Seeder
  alias OliWeb.Common.Utils

  @notice "This submission is no longer awaiting scoring."

  defp add_attempt(map, resource_attempt_tag, activity_tag, tag, state, attrs) do
    map
    |> Seeder.create_activity_attempt(
      Map.merge(
        %{attempt_number: 1, transformed_model: %{some: :thing}, lifecycle_state: state},
        Map.take(attrs, [:date_submitted])
      ),
      activity_tag,
      resource_attempt_tag,
      tag
    )
    |> Seeder.create_part_attempt(
      %{
        attempt_number: 1,
        grading_approach: :manual,
        lifecycle_state: state,
        response: %{"input" => attrs.response}
      },
      %Part{id: "1", responses: [], hints: [], grading_approach: :manual},
      tag
    )
  end

  defp create_queue(%{conn: conn, instructor: instructor}) do
    short_answer = Oli.Activities.get_registration_by_slug("oli_short_answer")

    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{family_name: "Alvarez", given_name: "Ana"}, :user_a)
      |> Seeder.add_user(%{family_name: "Bermudez", given_name: "Bea"}, :user_b)
      |> Seeder.add_user(%{family_name: "Castro", given_name: "Cara"}, :user_c)
      |> Seeder.add_activity(
        %{title: "Essay one"},
        :publication,
        :project,
        :author,
        :act_1,
        short_answer.id
      )
      |> Seeder.add_activity(
        %{title: "Essay two"},
        :publication,
        :project,
        :author,
        :act_2,
        short_answer.id
      )
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user_a, :page1, :revision1, :ra_a)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user_b, :page1, :revision1, :ra_b)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user_c, :page2, :revision2, :ra_c)
      |> add_attempt(:ra_a, :act_1, :a_1, :submitted, %{
        date_submitted: ~U[2026-10-01 10:00:00Z],
        response: "Ana wrote about essay one"
      })
      |> add_attempt(:ra_a, :act_2, :a_2, :submitted, %{
        date_submitted: ~U[2026-10-02 10:00:00Z],
        response: "Ana wrote about essay two"
      })
      |> add_attempt(:ra_b, :act_1, :b_1, :submitted, %{
        date_submitted: ~U[2026-10-03 10:00:00Z],
        response: "Bea wrote her essay"
      })
      |> add_attempt(:ra_c, :act_2, :c_scored, :evaluated, %{
        date_submitted: ~U[2026-10-04 10:00:00Z],
        response: "Cara was already scored"
      })

    enroll_user_to_section(instructor, map.section, :context_instructor)

    for tag <- [:user_a, :user_b, :user_c],
        do: enroll_user_to_section(map[tag], map.section, :context_learner)

    {:ok,
     Map.merge(map, %{
       conn: conn,
       table_route: ~p"/sections/#{map.section.slug}/scoring",
       scoring_route: fn id -> ~p"/sections/#{map.section.slug}/scoring/#{id}" end
     })}
  end

  defp query(path),
    do: path |> URI.parse() |> Map.get(:query) |> Kernel.||("") |> Plug.Conn.Query.decode()

  defp doc(html), do: Floki.parse_document!(html)
  defp text(doc, selector), do: doc |> Floki.find(selector) |> Floki.text() |> String.trim()

  defp href(doc, selector),
    do: doc |> Floki.find(selector) |> Floki.attribute("href") |> List.first()

  # Like the browser: one change per edited input, which `_target` names.
  defp change_draft(view, fields) do
    Enum.reduce(fields, nil, fn {name, value}, _html ->
      view |> form("#scoring-form", %{name => value}) |> render_change(%{"_target" => [name]})
    end)
  end

  defp table_date_cell(ctx, attempt_id) do
    {:ok, _view, html} = live(ctx.conn, ctx.table_route)

    html
    |> doc()
    |> Floki.find("tr##{attempt_id} td")
    |> Enum.at(5)
    |> Floki.text()
    |> String.trim()
  end

  describe "opening a submission" do
    setup [:instructor_conn, :create_queue]

    test "shows the student name as the heading, the activity, the submission date as the table shows it, and the position",
         ctx do
      {:ok, _view, html} = live(ctx.conn, ctx.scoring_route.(ctx.a_2.id))
      d = doc(html)

      assert text(d, "h1#scoring-heading") == Utils.name(ctx.user_a)
      assert [_] = Floki.find(d, ~s(h1#scoring-heading[tabindex="-1"]))
      assert text(d, "#submission-meta") =~ "Essay two"
      assert text(d, "#submission-meta") =~ "Submitted " <> table_date_cell(ctx, ctx.a_2.id)
      assert text(d, "#submission-position") == "2 of 3"
      assert html =~ "Ana wrote about essay two"
      refute html =~ "Bea wrote her essay"
    end

    test "Previous and Next walk the table's order, show the right student's answer, and are disabled at the ends",
         ctx do
      {:ok, view, html} = live(ctx.conn, ctx.scoring_route.(ctx.b_1.id))
      d = doc(html)

      assert text(d, "#submission-position") == "1 of 3"
      assert [_] = Floki.find(d, ~s|a#previous-link[aria-disabled="true"]:not([href])|)
      assert href(d, "a#next-link") == ctx.scoring_route.(ctx.a_2.id)

      assert_push_event(view, "scoring:focus_heading", %{})

      view |> element("a#next-link") |> render_click()
      assert_patch(view, ctx.scoring_route.(ctx.a_2.id))
      assert_push_event(view, "scoring:focus_heading", %{})
      d = doc(render(view))
      assert text(d, "h1#scoring-heading") == Utils.name(ctx.user_a)
      assert [_] = Floki.find(d, ~s|h1#scoring-heading[phx-hook="ScoringHeading"]|)
      assert text(d, "#submission-position") == "2 of 3"
      assert render(view) =~ "Ana wrote about essay two"
      refute render(view) =~ "Bea wrote her essay"

      view |> element("a#next-link") |> render_click()
      assert_patch(view, ctx.scoring_route.(ctx.a_1.id))
      d = doc(render(view))
      assert text(d, "#submission-position") == "3 of 3"
      assert [_] = Floki.find(d, ~s|a#next-link[aria-disabled="true"]:not([href])|)
      assert href(d, "a#previous-link") == ctx.scoring_route.(ctx.a_2.id)
    end

    test "the queue follows the filters and sort of the URL, and the links carry them", ctx do
      params = "?selected_user_ids=[#{ctx.user_a.id}]&sort_by=date_submitted&sort_order=asc"
      {:ok, _view, html} = live(ctx.conn, ctx.scoring_route.(ctx.a_1.id) <> params)
      d = doc(html)

      assert text(d, "#submission-position") == "1 of 2"
      assert [_] = Floki.find(d, ~s(a#previous-link[aria-disabled="true"]))
      next = href(d, "a#next-link")
      assert String.starts_with?(next, ctx.scoring_route.(ctx.a_2.id))

      assert query(next) == %{
               "selected_user_ids" => "[#{ctx.user_a.id}]",
               "sort_by" => "date_submitted",
               "sort_order" => "asc"
             }
    end

    test "a legacy filter in the URL shapes the queue and reaches the links as its modern equivalent",
         ctx do
      {:ok, _view, html} =
        live(ctx.conn, ctx.scoring_route.(ctx.a_1.id) <> "?user_id=#{ctx.user_a.id}")

      d = doc(html)

      assert text(d, "#submission-position") == "2 of 2"
      assert query(href(d, "a#previous-link")) == %{"selected_user_ids" => "[#{ctx.user_a.id}]"}
      assert query(href(d, "a#back-to-table")) == %{"selected_user_ids" => "[#{ctx.user_a.id}]"}
    end

    test "a deep link to a pending submission excluded by the filters shows no queue navigation",
         ctx do
      {:ok, view, html} =
        live(ctx.conn, ctx.scoring_route.(ctx.a_1.id) <> "?selected_user_ids=[#{ctx.user_b.id}]")

      d = doc(html)

      assert text(d, "h1#scoring-heading") == Utils.name(ctx.user_a)
      assert Floki.find(d, "#submission-position") == []
      assert Floki.find(d, "a#previous-link[href]") == []
      assert Floki.find(d, "a#next-link[href]") == []
      assert [_] = Floki.find(d, "a#back-to-table[href]")

      # scoring it does not invent a queue either: there was never an anchor to walk from
      g =
        Oli.Delivery.Attempts.Core.get_latest_part_attempts(ctx.a_1.attempt_guid)
        |> hd()
        |> Map.get(:attempt_guid)

      html =
        view
        |> form("#scoring-form", %{"score_#{g}" => "1", "feedback_#{g}" => "Done"})
        |> render_submit()

      assert html =~ "applied successfully"
      assert Floki.find(doc(html), "a#previous-link[href]") == []
      assert Floki.find(doc(html), "a#next-link[href]") == []
    end

    test "Back and the breadcrumb return to the table with the same params; the breadcrumb ends with the student",
         ctx do
      params =
        "?selected_user_ids=[#{ctx.user_a.id}]&sort_by=user&sort_order=asc&text_search=Alv&offset=0"

      {:ok, _view, html} = live(ctx.conn, ctx.scoring_route.(ctx.a_1.id) <> params)
      d = doc(html)

      back = href(d, "a#back-to-table")
      assert String.starts_with?(back, ctx.table_route)

      assert query(back) == %{
               "selected_user_ids" => "[#{ctx.user_a.id}]",
               "sort_by" => "user",
               "sort_order" => "asc",
               "text_search" => "Alv",
               "offset" => "0"
             }

      crumbs = Floki.find(d, ~s(nav[aria-label="breadcrumb"] li))
      assert crumbs |> List.last() |> Floki.text() |> String.trim() == Utils.name(ctx.user_a)

      assert [crumb_link] =
               Floki.find(d, ~s(nav[aria-label="breadcrumb"] a[href^="#{ctx.table_route}"]))

      assert query(Floki.attribute(crumb_link, "href") |> List.first()) == query(back)
    end
  end

  describe "the parts of a submission" do
    setup [:instructor_conn, :create_queue]

    setup ctx do
      # Authored "2" before "1"; stored "1" first. Database order and part id order both say
      # "1", "2" — only the authored order says "2", "1".
      authored = fn id ->
        %{
          "id" => id,
          "responses" => [],
          "hints" => [],
          "gradingApproach" => "manual",
          "outOf" => 1
        }
      end

      Oli.Repo.update!(
        Ecto.Changeset.change(ctx.act_2.revision,
          content: %{"authoring" => %{"parts" => [authored.("2"), authored.("1")]}}
        )
      )

      map =
        ctx
        |> Seeder.create_activity_attempt(
          %{
            attempt_number: 1,
            transformed_model: %{some: :thing},
            lifecycle_state: :submitted,
            date_submitted: ~U[2026-09-30 11:00:00Z]
          },
          :act_2,
          :ra_b,
          :authored
        )
        |> Seeder.create_part_attempt(
          %{attempt_number: 1, grading_approach: :manual, lifecycle_state: :submitted},
          %Part{id: "1", responses: [], hints: [], grading_approach: :manual},
          :authored,
          :part_one
        )
        |> Seeder.create_part_attempt(
          %{attempt_number: 1, grading_approach: :manual, lifecycle_state: :submitted},
          %Part{id: "2", responses: [], hints: [], grading_approach: :manual},
          :authored,
          :part_two
        )

      {:ok, Map.take(map, [:authored, :part_one, :part_two])}
    end

    test "open on the first part in authored order and are listed in that order", ctx do
      {:ok, _view, html} = live(ctx.conn, ctx.scoring_route.(ctx.authored.id))
      d = doc(html)
      first = ctx.part_two.attempt_guid
      second = ctx.part_one.attempt_guid

      assert Floki.attribute(d, ~s|button[id^="select_"]|, "id") == [
               "select_#{first}",
               "select_#{second}"
             ]

      assert [_] = Floki.find(d, "#part_#{first}:not([hidden])")
      assert [_] = Floki.find(d, "#part_#{second}[hidden]")
    end
  end

  defp add_two_part_submission(ctx) do
    map =
      ctx
      |> Seeder.create_activity_attempt(
        %{
          attempt_number: 1,
          transformed_model: %{some: :thing},
          lifecycle_state: :submitted,
          date_submitted: ~U[2026-09-30 10:00:00Z]
        },
        :act_2,
        :ra_b,
        :two_parts
      )
      |> Seeder.create_part_attempt(
        %{
          attempt_number: 1,
          grading_approach: :manual,
          lifecycle_state: :submitted,
          response: %{"input" => "first part"}
        },
        %Part{id: "1", responses: [], hints: [], grading_approach: :manual},
        :two_parts,
        :part_1
      )
      |> Seeder.create_part_attempt(
        %{
          attempt_number: 1,
          grading_approach: :manual,
          lifecycle_state: :submitted,
          response: %{"input" => "second part"}
        },
        %Part{id: "2", responses: [], hints: [], grading_approach: :manual},
        :two_parts,
        :part_2
      )

    {:ok, Map.take(map, [:two_parts, :part_1, :part_2])}
  end

  describe "the scoring form" do
    setup [:instructor_conn, :create_queue, :add_two_part_submission]

    setup ctx do
      {:ok, view, html} = live(ctx.conn, ctx.scoring_route.(ctx.two_parts.id))
      {:ok, view: view, html: html, g1: ctx.part_1.attempt_guid, g2: ctx.part_2.attempt_guid}
    end

    test "renders one form with every manual part's inputs; only the selected part is visible",
         ctx do
      d = doc(ctx.html)

      assert [_] =
               Floki.find(
                 d,
                 ~s|form#scoring-form[phx-change="draft_changed"][phx-submit="apply"][novalidate]|
               )

      for g <- [ctx.g1, ctx.g2] do
        assert [_] = Floki.find(d, ~s|#scoring-form input[name="score_#{g}"][data-initial=""]|)

        assert [_] =
                 Floki.find(d, ~s|#scoring-form textarea[name="feedback_#{g}"][data-initial=""]|)
      end

      assert [_] = Floki.find(d, "#part_#{ctx.g1}:not([hidden])")
      assert [_] = Floki.find(d, "#part_#{ctx.g2}[hidden]")
      assert Floki.find(d, ~s|#scoring-form input[name^="out_of_"]|) == []
    end

    test "two inputs of the same type carry the number of the submission they select", ctx do
      d = doc(ctx.html)
      heading = "#scoring-tabs-tabpanel-review .text-lg"

      assert text(d, "button#select_#{ctx.g1}") == "Short Answer 1"
      assert text(d, "button#select_#{ctx.g2}") == "Short Answer 2"
      assert text(d, heading) == "Part 1"

      html = ctx.view |> element("button#select_#{ctx.g2}") |> render_click()
      assert text(doc(html), heading) == "Part 2"
    end

    test "echoes the draft back into the inputs after each change, so unfocused inputs keep it",
         ctx do
      html =
        change_draft(ctx.view, %{"score_#{ctx.g1}" => "3", "feedback_#{ctx.g1}" => "Good start"})

      d = doc(html)
      assert [_] = Floki.find(d, ~s|input[name="score_#{ctx.g1}"][value="3"]|)
      assert text(d, ~s|textarea[name="feedback_#{ctx.g1}"]|) == "Good start"
      assert [_] = Floki.find(d, ~s|input[name="score_#{ctx.g1}"][data-initial=""]|)
    end

    test "Apply stays disabled until every manual part has both a score and feedback", ctx do
      assert [_] = Floki.find(doc(ctx.html), "button#apply-button[disabled]")

      # both scores present, one feedback blank: feedback alone must keep Apply disabled
      html =
        change_draft(ctx.view, %{
          "score_#{ctx.g1}" => "3",
          "feedback_#{ctx.g1}" => "Good",
          "score_#{ctx.g2}" => "0",
          "feedback_#{ctx.g2}" => "   "
        })

      assert [_] = Floki.find(doc(html), "button#apply-button[disabled]")

      # both feedbacks present, the FIRST part's score blank: every part counts, not only the last
      html =
        change_draft(ctx.view, %{
          "score_#{ctx.g1}" => "",
          "feedback_#{ctx.g1}" => "Good",
          "score_#{ctx.g2}" => "0",
          "feedback_#{ctx.g2}" => "Missing"
        })

      assert [_] = Floki.find(doc(html), "button#apply-button[disabled]")

      html =
        change_draft(ctx.view, %{
          "score_#{ctx.g1}" => "3",
          "feedback_#{ctx.g1}" => "Good",
          "score_#{ctx.g2}" => "0",
          "feedback_#{ctx.g2}" => "Missing"
        })

      assert [_] = Floki.find(doc(html), "button#apply-button:not([disabled])")
    end

    test "a change takes only the input it names, so a late one cannot blank the rest of the draft",
         ctx do
      change_draft(ctx.view, %{
        "score_#{ctx.g1}" => "1",
        "feedback_#{ctx.g1}" => "kept",
        "score_#{ctx.g2}" => "2"
      })

      # A debounced change sent from the blank page a reconnect renders, before its recovery lands.
      html =
        ctx.view
        |> form("#scoring-form", %{
          "score_#{ctx.g1}" => "",
          "feedback_#{ctx.g1}" => "",
          "score_#{ctx.g2}" => "",
          "feedback_#{ctx.g2}" => "late"
        })
        |> render_change(%{"_target" => ["feedback_#{ctx.g2}"]})

      d = doc(html)
      assert [_] = Floki.find(d, ~s|input[name="score_#{ctx.g1}"][value="1"]|)
      assert text(d, ~s|textarea[name="feedback_#{ctx.g1}"]|) == "kept"
      assert [_] = Floki.find(d, ~s|input[name="score_#{ctx.g2}"][value="2"]|)
      assert text(d, ~s|textarea[name="feedback_#{ctx.g2}"]|) == "late"
      assert [_] = Floki.find(d, "button#apply-button:not([disabled])")
    end

    test "clearing an input clears it in the draft and disables Apply again", ctx do
      html =
        change_draft(ctx.view, %{
          "score_#{ctx.g1}" => "1",
          "feedback_#{ctx.g1}" => "Good",
          "score_#{ctx.g2}" => "2",
          "feedback_#{ctx.g2}" => "Fine"
        })

      assert [_] = Floki.find(doc(html), "button#apply-button:not([disabled])")

      d = doc(change_draft(ctx.view, %{"score_#{ctx.g1}" => ""}))
      assert [_] = Floki.find(d, ~s|input[name="score_#{ctx.g1}"][value=""]|)
      assert [_] = Floki.find(d, "button#apply-button[disabled]")
    end

    test "after a reconnect, the recovered form restores every input of the draft", ctx do
      assert [_] =
               Floki.find(doc(ctx.html), ~s|form#scoring-form[phx-auto-recover="recover_draft"]|)

      # LiveView names the form's first input as the target of a recovery; every input counts.
      html =
        render_hook(ctx.view, "recover_draft", %{
          "score_#{ctx.g1}" => "1",
          "feedback_#{ctx.g1}" => "first",
          "score_#{ctx.g2}" => "2",
          "feedback_#{ctx.g2}" => "second",
          "_target" => ["score_#{ctx.g1}"]
        })

      d = doc(html)
      assert [_] = Floki.find(d, ~s|input[name="score_#{ctx.g1}"][value="1"]|)
      assert text(d, ~s|textarea[name="feedback_#{ctx.g1}"]|) == "first"
      assert [_] = Floki.find(d, ~s|input[name="score_#{ctx.g2}"][value="2"]|)
      assert text(d, ~s|textarea[name="feedback_#{ctx.g2}"]|) == "second"
      assert [_] = Floki.find(d, "button#apply-button:not([disabled])")
    end

    test "selecting another part shows it and keeps the first part's draft in the form", ctx do
      change_draft(ctx.view, %{"score_#{ctx.g1}" => "2", "feedback_#{ctx.g1}" => "Keep me"})

      html = ctx.view |> element("button#select_#{ctx.g2}") |> render_click()
      d = doc(html)

      assert [_] = Floki.find(d, "#part_#{ctx.g1}[hidden]")
      assert [_] = Floki.find(d, "#part_#{ctx.g2}:not([hidden])")
      assert [_] = Floki.find(d, ~s|input[name="score_#{ctx.g1}"][value="2"]|)
      assert text(d, ~s|textarea[name="feedback_#{ctx.g1}"]|) == "Keep me"
      assert [_] = Floki.find(d, ~s|button#select_#{ctx.g2}[aria-pressed="true"]|)
    end

    test "forged keys, foreign guids and unknown tabs or events are ignored", ctx do
      draft = %{"score_#{ctx.g1}" => "1", "feedback_#{ctx.g1}" => "ok"}
      change_draft(ctx.view, draft)

      html =
        [
          {"score_not-a-part", "9"},
          {"out_of_#{ctx.g1}", "99"},
          {"score_#{ctx.g2}", %{"n" => "1"}}
        ]
        |> Enum.map(fn {name, value} ->
          payload = Map.merge(draft, %{name => value, "_target" => [name]})
          render_hook(ctx.view, "draft_changed", payload)
        end)
        |> List.last()

      d = doc(html)
      assert [_] = Floki.find(d, ~s|input[name="score_#{ctx.g1}"][value="1"]|)
      assert [_] = Floki.find(d, ~s|input[name="score_#{ctx.g2}"][value=""]|)
      refute html =~ "not-a-part"

      html = render_hook(ctx.view, "select_part", %{"guid" => "not-a-part"})
      assert [_] = Floki.find(doc(html), "#part_#{ctx.g1}:not([hidden])")

      html = render_hook(ctx.view, "change_tab", %{"tab" => "evil"})
      assert [_] = Floki.find(doc(html), ~s|#scoring-tabs [role="tab"][aria-selected="true"]|)

      assert text(doc(html), ~s|#scoring-tabs [role="tab"][aria-selected="true"]|) ==
               "Student Submission"

      assert render_hook(ctx.view, "no_such_event", %{"a" => 1}) =~ "scoring-form"
    end

    test "the unsaved-changes modal: Stay keeps the draft; Discard clears it and tells the client to proceed",
         ctx do
      change_draft(ctx.view, %{"score_#{ctx.g1}" => "2", "feedback_#{ctx.g1}" => "Draft"})

      assert Floki.find(doc(render(ctx.view)), "#unsaved-modal") == []

      html = render_hook(ctx.view, "show_unsaved_changes_modal", %{})
      d = doc(html)
      assert [_] = Floki.find(d, ~s|#unsaved-modal [role="dialog"]|)
      assert html =~ "You have unapplied scores or feedback for this submission."
      assert text(d, "button#modal-stay") == "Stay"
      assert text(d, "button#modal-discard") == "Discard and leave"

      html = ctx.view |> element("button#modal-stay") |> render_click()
      assert Floki.find(doc(html), "#unsaved-modal") == []
      assert [_] = Floki.find(doc(html), ~s|input[name="score_#{ctx.g1}"][value="2"]|)

      render_hook(ctx.view, "show_unsaved_changes_modal", %{})
      html = ctx.view |> element("button#modal-discard") |> render_click()
      assert_push_event(ctx.view, "unsaved_changes:proceed", %{})
      assert Floki.find(doc(html), "#unsaved-modal") == []
      assert [_] = Floki.find(doc(html), ~s|input[name="score_#{ctx.g1}"][value=""]|)
    end

    test "every feedback field keeps the 2000-character limit", ctx do
      limits =
        ctx.html
        |> doc()
        |> Floki.find("#scoring-form textarea")
        |> Enum.map(&{Floki.attribute(&1, "name"), Floki.attribute(&1, "maxlength")})

      assert limits == [
               {["feedback_#{ctx.g1}"], ["2000"]},
               {["feedback_#{ctx.g2}"], ["2000"]}
             ]
    end

    test "labels are associated with the fields and the feedback-required message is announced",
         ctx do
      d = doc(ctx.html)
      assert [_] = Floki.find(d, ~s|label[for="score_#{ctx.g1}"]|)
      assert [_] = Floki.find(d, ~s|label[for="feedback_#{ctx.g1}"]|)
      assert Floki.find(d, "#feedback_error_#{ctx.g1}") == []

      html =
        change_draft(ctx.view, %{"score_#{ctx.g1}" => "2", "feedback_#{ctx.g1}" => "   "})

      d = doc(html)

      assert text(d, ~s|[aria-live="polite"] #feedback_error_#{ctx.g1}|) ==
               "Add feedback for this input to enable Apply Score and Feedback."

      assert [_] =
               Floki.find(
                 d,
                 ~s|textarea[name="feedback_#{ctx.g1}"][aria-invalid="true"][aria-describedby~="feedback_error_#{ctx.g1}"]|
               )
    end
  end

  defp add_mixed_submission(ctx) do
    map =
      ctx
      |> Seeder.create_activity_attempt(
        %{
          attempt_number: 1,
          transformed_model: %{some: :thing},
          lifecycle_state: :submitted,
          date_submitted: ~U[2026-09-29 10:00:00Z]
        },
        :act_1,
        :ra_c,
        :mixed
      )
      |> Seeder.create_part_attempt(
        %{
          attempt_number: 1,
          grading_approach: :manual,
          lifecycle_state: :submitted,
          response: %{"input" => "manual part"}
        },
        %Part{id: "1", responses: [], hints: [], grading_approach: :manual},
        :mixed,
        :mixed_manual
      )
      |> Seeder.create_part_attempt(
        %{
          attempt_number: 1,
          grading_approach: :automatic,
          lifecycle_state: :evaluated,
          score: 1.0,
          out_of: 1.0,
          response: %{"input" => "auto part"},
          feedback: %{
            "content" => [
              %{"type" => "p", "children" => [%{"text" => "Machine feedback for the auto part"}]}
            ]
          }
        },
        %Part{id: "2", responses: [], hints: [], grading_approach: :automatic},
        :mixed,
        :mixed_auto
      )

    {:ok, Map.take(map, [:mixed, :mixed_manual, :mixed_auto])}
  end

  defp add_partly_scored_submission(ctx) do
    map =
      ctx
      |> Seeder.create_activity_attempt(
        %{
          attempt_number: 1,
          transformed_model: %{some: :thing},
          lifecycle_state: :submitted,
          date_submitted: ~U[2026-09-28 10:00:00Z]
        },
        :act_1,
        :ra_b,
        :partly
      )
      |> Seeder.create_part_attempt(
        %{
          attempt_number: 1,
          grading_approach: :manual,
          lifecycle_state: :evaluated,
          score: 0.75,
          out_of: 1.0,
          response: %{"input" => "scored earlier"},
          feedback: %{
            "content" => [%{"type" => "p", "children" => [%{"text" => "Scored earlier by hand"}]}]
          }
        },
        %Part{id: "1", responses: [], hints: [], grading_approach: :manual},
        :partly,
        :partly_done
      )
      |> Seeder.create_part_attempt(
        %{
          attempt_number: 1,
          grading_approach: :manual,
          lifecycle_state: :submitted,
          response: %{"input" => "still pending"}
        },
        %Part{id: "2", responses: [], hints: [], grading_approach: :manual},
        :partly,
        :partly_pending
      )

    {:ok, Map.take(map, [:partly, :partly_done, :partly_pending])}
  end

  describe "narrow screens: the selected input inside the panel" do
    setup [:instructor_conn, :create_queue, :add_two_part_submission]

    @narrow ~s|#scoring-panel [phx-hook="ManualGradingMobileFocus"]|

    test "the panel carries the selected input's answer and its own tabs, and follows the selection",
         ctx do
      {:ok, view, html} = live(ctx.conn, ctx.scoring_route.(ctx.two_parts.id))
      d = doc(html)
      g1 = ctx.part_1.attempt_guid
      g2 = ctx.part_2.attempt_guid

      assert [_] = Floki.find(d, ~s|#{@narrow}[data-selected-part-attempt-guid="#{g1}"]|)
      assert text(d, @narrow) =~ "first part"
      refute text(d, @narrow) =~ "second part"
      assert [_, _] = Floki.find(d, ~s|#{@narrow} [role="tab"]|)

      d = view |> element("button#select_#{g2}") |> render_click() |> doc()

      assert [_] = Floki.find(d, ~s|#{@narrow}[data-selected-part-attempt-guid="#{g2}"]|)
      assert text(d, @narrow) =~ "second part"
      refute text(d, @narrow) =~ "first part"
    end

    test "the Activity Details tab shows the activity in both copies, each under its own ids",
         ctx do
      {:ok, view, _html} = live(ctx.conn, ctx.scoring_route.(ctx.two_parts.id))

      # LiveViewTest raises on any duplicate id in the render, so reaching the asserts is the check
      d = view |> element("#scoring-context-tabs-tab-preview") |> render_click() |> doc()

      assert [_] = Floki.find(d, "#scoring-preview oli-short-answer-authoring")

      assert [_] =
               Floki.find(d, ~s|#{@narrow} #scoring-preview-narrow oli-short-answer-authoring|)
    end
  end

  describe "manual parts already evaluated (stale attempts)" do
    setup [:instructor_conn, :create_queue, :add_partly_scored_submission]

    test "an evaluated manual part is read-only with its saved values and not required for Apply",
         ctx do
      {:ok, view, html} = live(ctx.conn, ctx.scoring_route.(ctx.partly.id))
      d = doc(html)
      done = ctx.partly_done.attempt_guid
      pending = ctx.partly_pending.attempt_guid

      assert Floki.find(d, ~s|input[name="score_#{done}"]|) == []
      assert text(d, "#part_#{done}") =~ "0.75"
      assert text(d, "#part_#{done}") =~ "Scored earlier by hand"
      refute text(d, "#part_#{done}") =~ "No feedback provided"
      assert [_] = Floki.find(d, ~s|input[name="score_#{pending}"]|)

      params = %{"score_#{pending}" => "1", "feedback_#{pending}" => "Now"}
      html = change_draft(view, params)
      assert [_] = Floki.find(doc(html), "button#apply-button:not([disabled])")

      html = view |> form("#scoring-form", params) |> render_submit()
      assert html =~ "applied successfully"
    end

    test "an evaluated manual part without feedback says no feedback was provided", ctx do
      Oli.Repo.update!(Ecto.Changeset.change(ctx.partly_done, feedback: nil))

      {:ok, _view, html} = live(ctx.conn, ctx.scoring_route.(ctx.partly.id))

      assert text(doc(html), "#part_#{ctx.partly_done.attempt_guid}") =~ "No feedback provided"
    end

    test "when every manual part is already evaluated, the attempt can be resolved and leaves the queue",
         ctx do
      Oli.Repo.update!(
        Ecto.Changeset.change(ctx.partly_pending,
          lifecycle_state: :evaluated,
          score: 1.0,
          out_of: 1.0
        )
      )

      {:ok, view, html} = live(ctx.conn, ctx.scoring_route.(ctx.partly.id))

      assert Floki.find(doc(html), "#scoring-form input") == []
      assert html =~ "Resolve Attempt State"

      html = view |> element("button", "Resolve Attempt State") |> render_click()
      assert html =~ "Stale attempt resolved."
      assert Floki.find(doc(html), "#submission-position") == []

      assert {:error, {:redirect, %{flash: %{"info" => @notice}}}} =
               live(ctx.conn, ctx.scoring_route.(ctx.partly.id))
    end
  end

  describe "an activity with an automatically graded part" do
    setup [:instructor_conn, :create_queue, :add_mixed_submission]

    test "shows the automatic part read-only and does not require it for Apply", ctx do
      {:ok, view, html} = live(ctx.conn, ctx.scoring_route.(ctx.mixed.id))
      d = doc(html)
      manual = ctx.mixed_manual.attempt_guid
      auto = ctx.mixed_auto.attempt_guid

      assert [_] = Floki.find(d, ~s|input[name="score_#{manual}"]|)
      assert Floki.find(d, ~s|input[name="score_#{auto}"]|) == []
      assert Floki.find(d, ~s|textarea[name="feedback_#{auto}"]|) == []
      assert [_] = Floki.find(d, "button#select_#{auto}")
      assert text(d, "#part_#{auto}") =~ "Automatically Graded"
      assert text(d, "#part_#{auto}") =~ "Machine feedback for the auto part"
      refute text(d, "#part_#{auto}") =~ "automatically graded by the system"

      html =
        change_draft(view, %{"score_#{manual}" => "1", "feedback_#{manual}" => "Done"})

      assert [_] = Floki.find(doc(html), "button#apply-button:not([disabled])")
    end

    test "an automatic part still awaiting its score is read-only too and Apply does not wait for it",
         ctx do
      Oli.Repo.update!(Ecto.Changeset.change(ctx.mixed_auto, lifecycle_state: :submitted))

      {:ok, view, html} = live(ctx.conn, ctx.scoring_route.(ctx.mixed.id))
      d = doc(html)
      manual = ctx.mixed_manual.attempt_guid
      auto = ctx.mixed_auto.attempt_guid

      assert [_] = Floki.find(d, ~s|input[name="score_#{manual}"]|)
      assert Floki.find(d, ~s|input[name="score_#{auto}"]|) == []
      assert Floki.find(d, ~s|textarea[name="feedback_#{auto}"]|) == []
      assert text(d, "#part_#{auto}") =~ "Automatically Graded"

      html =
        change_draft(view, %{"score_#{manual}" => "1", "feedback_#{manual}" => "Done"})

      assert [_] = Floki.find(doc(html), "button#apply-button:not([disabled])")
    end

    test "an automatic part without feedback says the system graded it", ctx do
      Oli.Repo.update!(Ecto.Changeset.change(ctx.mixed_auto, feedback: nil))

      {:ok, _view, html} = live(ctx.conn, ctx.scoring_route.(ctx.mixed.id))

      assert text(doc(html), "#part_#{ctx.mixed_auto.attempt_guid}") =~
               "This part was automatically graded by the system"
    end
  end

  describe "Apply" do
    setup [:instructor_conn, :create_queue, :add_two_part_submission]

    setup ctx do
      {:ok, view, _html} = live(ctx.conn, ctx.scoring_route.(ctx.two_parts.id))
      {:ok, view: view, g1: ctx.part_1.attempt_guid, g2: ctx.part_2.attempt_guid}
    end

    defp part_states(ctx) do
      ctx.two_parts.attempt_guid
      |> Oli.Delivery.Attempts.Core.get_latest_part_attempts()
      |> Map.new(&{&1.attempt_guid, {&1.lifecycle_state, &1.score, &1.feedback}})
    end

    defp valid(ctx),
      do: %{
        "score_#{ctx.g1}" => "1",
        "feedback_#{ctx.g1}" => "Well done",
        "score_#{ctx.g2}" => "0.5",
        "feedback_#{ctx.g2}" => "Half"
      }

    test "saves the scores, says so, and stays on the submission read-only with the saved values",
         ctx do
      html = ctx.view |> form("#scoring-form", valid(ctx)) |> render_submit()
      d = doc(html)

      assert html =~ "Score and feedback applied successfully."
      states = part_states(ctx)
      assert {:evaluated, 1.0, _} = states[ctx.g1]
      assert {:evaluated, 0.5, _} = states[ctx.g2]

      # the parts are now evaluated: they show their saved score and feedback, with no inputs
      assert Floki.find(d, "#scoring-form input, #scoring-form textarea") == []
      assert text(d, "#part_#{ctx.g1}") =~ "1.0 / 1.0"
      assert text(d, "#part_#{ctx.g1}") =~ "Well done"
      assert text(d, "#part_#{ctx.g2}") =~ "0.5 / 1.0"
      assert Floki.find(d, "button#apply-button") == []
      assert Floki.find(d, "#submission-position") == []
      assert text(d, "h1#scoring-heading") == Utils.name(ctx.user_b)
      # neighbours still come from the anchor captured when the submission was opened
      assert href(d, "a#previous-link") == ctx.scoring_route.(ctx.a_1.id)
      assert [_] = Floki.find(d, ~s|a#next-link[aria-disabled="true"]|)
    end

    test "after Apply nothing is left to lose: leaving goes on without asking", ctx do
      ctx.view |> form("#scoring-form", valid(ctx)) |> render_submit()

      html = render_hook(ctx.view, "show_unsaved_changes_modal", %{})

      assert_push_event(ctx.view, "unsaved_changes:proceed", %{})
      assert Floki.find(doc(html), ~s|#unsaved-modal [role="dialog"]|) == []
    end

    test "a reload after Apply redirects to the table with the notice", ctx do
      ctx.view |> form("#scoring-form", valid(ctx)) |> render_submit()

      assert {:error, {:redirect, %{flash: %{"info" => @notice}}}} =
               live(ctx.conn, ctx.scoring_route.(ctx.two_parts.id))
    end

    test "the server rejects a submit with a blank feedback: nothing is scored and the draft stays",
         ctx do
      params = Map.put(valid(ctx), "feedback_#{ctx.g2}", "   ")
      html = ctx.view |> form("#scoring-form", params) |> render_submit()

      refute html =~ "applied successfully"
      assert {:submitted, nil, nil} = part_states(ctx)[ctx.g2]

      assert [_] =
               Floki.find(doc(html), ~s|input[name="score_#{ctx.g1}"][value="1"]:not([readonly])|)

      assert [_] = Floki.find(doc(html), "button#apply-button[disabled]")
    end

    test "a score that is not a number is not a score: Apply stays disabled and a submit scores nothing",
         ctx do
      params = Map.put(valid(ctx), "score_#{ctx.g2}", "abc")
      html = change_draft(ctx.view, params)
      assert [_] = Floki.find(doc(html), "button#apply-button[disabled]")

      html = ctx.view |> form("#scoring-form", params) |> render_submit()
      refute html =~ "applied successfully"
      assert {:submitted, nil, nil} = part_states(ctx)[ctx.g1]
    end

    test "a score too long to be a float is not a score either: the page stays up, Apply stays disabled and a submit scores nothing",
         ctx do
      html = change_draft(ctx.view, valid(ctx))
      assert [_] = Floki.find(doc(html), "button#apply-button:not([disabled])")

      # Float.parse/1 raises on 309 digits instead of returning :error.
      params = Map.put(valid(ctx), "score_#{ctx.g2}", String.duplicate("9", 309))
      html = change_draft(ctx.view, params)
      assert [_] = Floki.find(doc(html), "button#apply-button[disabled]")

      html = ctx.view |> form("#scoring-form", params) |> render_submit()
      refute html =~ "applied successfully"
      assert {:submitted, nil, nil} = part_states(ctx)[ctx.g1]
      assert {:submitted, nil, nil} = part_states(ctx)[ctx.g2]
    end

    # Submitted straight to the server, so the browser's own clamp never runs. Persistence keeps
    # every score within the maximum it receives; the page owns sending the authored maximum.
    test "a score above the part's maximum is saved as the maximum the activity authors", ctx do
      part = fn id, out_of ->
        %{
          "id" => id,
          "responses" => [],
          "hints" => [],
          "gradingApproach" => "manual",
          "outOf" => out_of
        }
      end

      Oli.Repo.update!(
        Ecto.Changeset.change(ctx.act_2.revision,
          content: %{"authoring" => %{"parts" => [part.("1", 1), part.("2", 2)]}}
        )
      )

      {:ok, view, _html} = live(ctx.conn, ctx.scoring_route.(ctx.two_parts.id))
      view |> form("#scoring-form", valid(ctx)) |> render_submit(%{"score_#{ctx.g2}" => "7"})

      stored = Oli.Delivery.Attempts.Core.get_part_attempt_by(attempt_guid: ctx.g2)
      assert {stored.score, stored.out_of} == {2.0, 2.0}
    end

    test "when someone else scored it meanwhile, Apply saves nothing, says so, and the draft stays visible read-only",
         ctx do
      change_draft(ctx.view, valid(ctx))

      {:ok, _} =
        Oli.Delivery.Attempts.ManualGrading.apply_manual_scoring(
          ctx.section,
          Oli.Delivery.Attempts.ManualGrading.fetch_submitted_attempt(
            ctx.section,
            ctx.two_parts.id
          ),
          %{
            ctx.g1 => %OliWeb.ManualGrading.ScoreFeedback{
              score: 0.0,
              out_of: 1.0,
              feedback: "Someone else"
            },
            ctx.g2 => %OliWeb.ManualGrading.ScoreFeedback{
              score: 0.0,
              out_of: 1.0,
              feedback: "Someone else"
            }
          }
        )

      html = ctx.view |> form("#scoring-form", valid(ctx)) |> render_submit()
      d = doc(html)

      assert html =~ "This submission was already scored by someone else."
      refute html =~ "applied successfully"
      assert {:evaluated, +0.0, _} = part_states(ctx)[ctx.g1]

      assert [_] =
               Floki.find(
                 d,
                 ~s|input[name="score_#{ctx.g1}"][readonly][value="1"][data-initial=""]|
               )

      assert Floki.find(d, "#submission-position") == []
      assert href(d, "a#previous-link") == ctx.scoring_route.(ctx.a_1.id)

      # scoring events are refused in this state: a forged draft change or form recovery does not
      # touch the draft
      forged = %{
        "score_#{ctx.g1}" => "9",
        "feedback_#{ctx.g1}" => "x",
        "_target" => ["score_#{ctx.g1}"]
      }

      html = render_hook(ctx.view, "draft_changed", forged)
      assert [_] = Floki.find(doc(html), ~s|input[name="score_#{ctx.g1}"][readonly][value="1"]|)

      html = render_hook(ctx.view, "recover_draft", forged)
      assert [_] = Floki.find(doc(html), ~s|input[name="score_#{ctx.g1}"][readonly][value="1"]|)

      # leaving still asks for confirmation, and Discard is accepted in this state
      html = render_hook(ctx.view, "show_unsaved_changes_modal", %{})
      assert [_] = Floki.find(doc(html), ~s|#unsaved-modal [role="dialog"]|)
      ctx.view |> element("button#modal-discard") |> render_click()
      assert_push_event(ctx.view, "unsaved_changes:proceed", %{})
    end
  end

  describe "scored by someone else while the draft is open" do
    setup [:instructor_conn, :create_queue, :add_two_part_submission]

    test "the next scoring event makes the form read-only with the draft, hides the counter, and Discard still works",
         ctx do
      {:ok, view, _html} = live(ctx.conn, ctx.scoring_route.(ctx.two_parts.id))
      g1 = ctx.part_1.attempt_guid
      g2 = ctx.part_2.attempt_guid

      change_draft(view, %{"score_#{g1}" => "1", "feedback_#{g1}" => "Draft"})

      {:ok, _} =
        Oli.Delivery.Attempts.ManualGrading.apply_manual_scoring(
          ctx.section,
          Oli.Delivery.Attempts.ManualGrading.fetch_submitted_attempt(
            ctx.section,
            ctx.two_parts.id
          ),
          %{
            g1 => %OliWeb.ManualGrading.ScoreFeedback{score: 0.0, out_of: 1.0, feedback: "Other"},
            g2 => %OliWeb.ManualGrading.ScoreFeedback{score: 0.0, out_of: 1.0, feedback: "Other"}
          }
        )

      html =
        change_draft(view, %{"feedback_#{g1}" => "Draft two"})

      d = doc(html)

      assert html =~ @notice

      assert [_] =
               Floki.find(d, ~s|input[name="score_#{g1}"][readonly][value="1"][data-initial=""]|)

      assert text(d, ~s|textarea[name="feedback_#{g1}"]|) == "Draft two"
      assert Floki.find(d, "#submission-position") == []
      assert Floki.find(d, "button#apply-button") == []

      render_hook(view, "show_unsaved_changes_modal", %{})
      view |> element("button#modal-discard") |> render_click()
      assert_push_event(view, "unsaved_changes:proceed", %{})
    end

    test "selecting a part after it was scored elsewhere also switches to read-only", ctx do
      {:ok, view, _html} = live(ctx.conn, ctx.scoring_route.(ctx.two_parts.id))
      Oli.Repo.update!(Ecto.Changeset.change(ctx.two_parts, lifecycle_state: :evaluated))

      html = view |> element("button#select_#{ctx.part_2.attempt_guid}") |> render_click()
      assert html =~ @notice

      assert [_] =
               Floki.find(doc(html), ~s|input[name="score_#{ctx.part_2.attempt_guid}"][readonly]|)
    end
  end

  describe "a submission that is not awaiting scoring" do
    setup [:instructor_conn, :create_queue]

    test "redirects to the table with the URL params and a notice: scored, other section, junk id",
         ctx do
      params = "?selected_user_ids=[#{ctx.user_a.id}]&sort_by=user"

      for id <- [
            ctx.c_scored.id,
            Oli.Factory.insert(:activity_attempt, lifecycle_state: :submitted).id,
            "abc",
            "0"
          ] do
        assert {:error, {:redirect, %{to: to, flash: %{"info" => @notice}}}} =
                 live(ctx.conn, ctx.scoring_route.(id) <> params),
               "attempt #{inspect(id)}"

        assert String.starts_with?(to, ctx.table_route)
        assert query(to)["selected_user_ids"] == "[#{ctx.user_a.id}]"
        assert query(to)["sort_by"] == "user"
      end
    end

    test "a filter value left with nothing pending keeps both notices on the table",
         ctx do
      # c_scored is user_c's only attempt and it is scored, so the table also drops user_c's filter.
      path = ctx.scoring_route.(ctx.c_scored.id) <> "?selected_user_ids=[#{ctx.user_c.id}]"
      redirect = live(ctx.conn, path)

      assert {:error, {:redirect, %{flash: %{"info" => @notice}}}} = redirect
      assert {:ok, conn} = follow_redirect(redirect, ctx.conn)

      # The table drops user_c's filter with a second redirect; the scoring notice stays in front.
      both =
        @notice <>
          " #{Utils.name(ctx.user_c)} has no more submissions awaiting scoring and was removed from the filter."

      assert redirected_to(conn) =~ ctx.table_route
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == both

      {:ok, _view, html} = live(conn, redirected_to(conn))
      assert html =~ both
    end

    test "Next to a submission scored meanwhile redirects to the table with the notice", ctx do
      {:ok, view, _html} = live(ctx.conn, ctx.scoring_route.(ctx.b_1.id))
      Oli.Repo.update!(Ecto.Changeset.change(ctx.a_2, lifecycle_state: :evaluated))

      view |> element("a#next-link") |> render_click()
      {path, flash} = assert_redirect(view)
      assert String.starts_with?(path, ctx.table_route)
      assert flash["info"] == @notice
    end
  end
end
