defmodule OliWeb.ManualGrading.ManualGradingViewLiveTest do
  use OliWeb.ConnCase

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  alias Oli.Activities.Model.Part
  alias Oli.Seeder
  alias OliWeb.Common.Utils

  defp add_attempt(map, resource_attempt_tag, activity_tag, tag, state) do
    map
    |> Seeder.create_activity_attempt(
      %{attempt_number: 1, transformed_model: %{some: :thing}, lifecycle_state: state},
      activity_tag,
      resource_attempt_tag,
      tag
    )
    |> Seeder.create_part_attempt(
      %{attempt_number: 1, grading_approach: :manual, lifecycle_state: state},
      %Part{id: "1", responses: [], hints: [], grading_approach: :manual},
      tag
    )
  end

  defp search_value(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("input#text-search-input")
    |> Floki.attribute("value")
  end

  defp create_queue(%{conn: conn, instructor: instructor}) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{family_name: "Alvarez", given_name: "Ana"}, :user_a)
      |> Seeder.add_user(%{family_name: "Bermudez", given_name: "Bea"}, :user_b)
      |> Seeder.add_user(%{family_name: "Castro", given_name: "Cara"}, :user_c)
      |> Seeder.add_activity(%{title: "Essay one"}, :publication, :project, :author, :act_1)
      |> Seeder.add_activity(%{title: "Essay two"}, :publication, :project, :author, :act_2)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user_a, :page1, :revision1, :ra_a)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user_b, :page1, :revision1, :ra_b)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user_c, :page2, :revision2, :ra_c)
      |> add_attempt(:ra_a, :act_1, :a_1, :submitted)
      |> add_attempt(:ra_a, :act_2, :a_2, :submitted)
      |> add_attempt(:ra_b, :act_1, :b_1, :submitted)
      |> add_attempt(:ra_c, :act_2, :c_scored, :evaluated)

    enroll_user_to_section(instructor, map.section, :context_instructor)

    for tag <- [:user_a, :user_b, :user_c],
        do: enroll_user_to_section(map[tag], map.section, :context_learner)

    {:ok, Map.merge(map, %{conn: conn, route: ~p"/sections/#{map.section.slug}/scoring"})}
  end

  defp query(path) do
    path |> URI.parse() |> Map.get(:query) |> Kernel.||("") |> Plug.Conn.Query.decode()
  end

  defp header_texts(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("thead th")
    |> Enum.map(&(&1 |> Floki.text() |> String.trim()))
  end

  defp row_students(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("tbody tr td:first-child")
    |> Enum.map(&(&1 |> Floki.text() |> String.trim()))
  end

  describe "table" do
    setup [:instructor_conn, :create_queue]

    test "the order comes from the URL alone: a URL without sort shows the default order the scoring queue uses",
         ctx do
      {:ok, view, html} = live(ctx.conn, ctx.route <> "?sort_by=user&sort_order=asc")
      by_student = row_students(html)
      {:ok, _fresh, fresh_html} = live(ctx.conn, ctx.route)
      default_order = row_students(fresh_html)

      assert by_student == ["Alvarez, Ana", "Alvarez, Ana", "Bermudez, Bea"]
      refute default_order == by_student

      assert row_students(render_patch(view, ctx.route)) == default_order
    end

    test "names the two attempt columns Activity Attempt and Page Attempt", ctx do
      {:ok, _view, html} = live(ctx.conn, ctx.route)

      headers = header_texts(html)
      assert "Activity Attempt" in headers
      assert "Page Attempt" in headers
      refute "Attempt" in headers
    end

    test "renders the design-system table with a fixed id, sort buttons and no page-size control",
         ctx do
      {:ok, _view, html} = live(ctx.conn, ctx.route)
      doc = Floki.parse_document!(html)

      assert [_] = Floki.find(doc, "table#manual-scoring-table")
      assert [_] = Floki.find(doc, ~s(th button[phx-value-sort_by="user"]))
      assert Floki.find(doc, ~s(select[name="limit"])) == []
    end

    test "shows 'Showing N of M submissions' only while a filter or search is active", ctx do
      {:ok, _view, html} = live(ctx.conn, ctx.route)
      refute html =~ ~r/Showing \d+ of \d+ submissions/

      {:ok, _view, html} = live(ctx.conn, ctx.route <> "?selected_user_ids=[#{ctx.user_a.id}]")
      assert html =~ "Showing 2 of 3 submissions"

      {:ok, _view, html} = live(ctx.conn, ctx.route <> "?text_search=Bermudez")
      assert html =~ "Showing 1 of 3 submissions"
    end

    test "Clear All Filters empties the filters and the search, goes to the first page and keeps the sort",
         ctx do
      {:ok, view, html} =
        live(
          ctx.conn,
          ctx.route <>
            "?text_search=Alvarez&selected_user_ids=[#{ctx.user_a.id}]" <>
            "&selected_activity_ids=[#{ctx.act_1.resource.id},#{ctx.act_2.resource.id}]" <>
            "&selected_page_ids=[#{ctx.page1.id}]&graded=false&sort_by=user&sort_order=asc&offset=1"
        )

      # two of Ana's rows match; offset 1 shows the second one only
      assert row_students(html) == [Utils.name(ctx.user_a)]
      assert search_value(html) == ["Alvarez"]

      view |> element("button", "Clear All Filters") |> render_click()
      path = assert_patch(view)

      assert %{
               "text_search" => "",
               "selected_user_ids" => "[]",
               "selected_activity_ids" => "[]",
               "selected_page_ids" => "[]",
               "graded" => "",
               "sort_by" => "user",
               "sort_order" => "asc",
               "offset" => "0"
             } = query(path)

      assert search_value(render(view)) == [""]

      assert row_students(render(view)) == [
               Utils.name(ctx.user_a),
               Utils.name(ctx.user_a),
               Utils.name(ctx.user_b)
             ]
    end

    test "shows the empty states for an empty queue and for filters that match nothing",
         %{conn: conn} = ctx do
      empty = Seeder.base_project_with_resource2() |> Seeder.create_section()
      enroll_user_to_section(ctx.instructor, empty.section, :context_instructor)

      {:ok, _view, html} = live(conn, ~p"/sections/#{empty.section.slug}/scoring")
      assert html =~ "No submissions awaiting scoring."

      {:ok, _view, html} = live(conn, ctx.route <> "?text_search=nothing-matches")
      assert html =~ "No submissions match your filters."
      refute html =~ "No submissions awaiting scoring."
    end

    test "the search input shows the applied search from the URL", ctx do
      {:ok, _view, html} = live(ctx.conn, ctx.route <> "?text_search=Bermudez")

      assert search_value(html) == ["Bermudez"]
      assert row_students(html) == [Utils.name(ctx.user_b)]
    end

    test "the sort params order the rows and a sort click patches them into the URL", ctx do
      a = Utils.name(ctx.user_a)
      b = Utils.name(ctx.user_b)

      {:ok, _view, html} = live(ctx.conn, ctx.route <> "?sort_by=user&sort_order=asc")
      assert row_students(html) == [a, a, b]

      {:ok, view, html} = live(ctx.conn, ctx.route <> "?sort_by=user&sort_order=desc")
      assert row_students(html) == [b, a, a]

      view |> element(~s(th button[phx-value-sort_by="user"])) |> render_click()
      path = assert_patch(view)
      assert %{"sort_by" => "user", "sort_order" => "asc"} = query(path)
      assert row_students(render(view)) == [a, a, b]
    end
  end

  describe "table filters" do
    setup [:instructor_conn, :create_queue]

    defp filter_values(html, filter) do
      html
      |> Floki.parse_document!()
      |> Floki.find(~s(##{filter}-panel input[type="checkbox"]))
      |> Enum.map(fn input ->
        {hd(Floki.attribute(input, "value")),
         input |> Floki.attribute("id") |> hd() |> then(&label_text(html, &1))}
      end)
    end

    defp label_text(html, input_id) do
      html
      |> Floki.parse_document!()
      |> Floki.find(~s(label[for="#{input_id}"]))
      |> Floki.text()
      |> String.trim()
    end

    defp apply_filter(view, filter, values) do
      view |> element("##{filter}-trigger") |> render_click()
      view |> element("##{filter}-form") |> render_submit(%{"selected" => values})
    end

    test "each filter offers only the values with submissions awaiting scoring", ctx do
      {:ok, _view, html} = live(ctx.conn, ctx.route)

      assert filter_values(html, "student-filter") == [
               {"#{ctx.user_a.id}", Utils.name(ctx.user_a)},
               {"#{ctx.user_b.id}", Utils.name(ctx.user_b)}
             ]

      assert filter_values(html, "activity-filter") == [
               {"#{ctx.act_1.resource.id}", "Essay one"},
               {"#{ctx.act_2.resource.id}", "Essay two"}
             ]

      assert filter_values(html, "page-filter") == [{"#{ctx.page1.id}", ctx.revision1.title}]
      assert filter_values(html, "purpose-filter") == [{"true", "Scored"}, {"false", "Practice"}]

      assert html =~ ~s(id="student-filter-search")

      refute html =~ ~s(id="purpose-filter-search")
    end

    test "options are listed alphabetically, not in the order the values were created", ctx do
      later =
        ctx
        |> Seeder.add_user(%{family_name: "Aguilar", given_name: "Al"}, :user_d)
        |> Seeder.create_resource_attempt(
          %{attempt_number: 1},
          :user_d,
          :page1,
          :revision1,
          :ra_d
        )
        |> add_attempt(:ra_d, :act_1, :d_1, :submitted)
        |> Seeder.add_activity(%{title: "Abstract"}, :publication, :project, :author, :act_0)
        |> add_attempt(:ra_d, :act_0, :d_0, :submitted)

      enroll_user_to_section(later.user_d, ctx.section, :context_learner)

      {:ok, _view, html} = live(ctx.conn, ctx.route)

      assert html |> filter_values("student-filter") |> Enum.map(&elem(&1, 1)) == [
               Utils.name(later.user_d),
               Utils.name(ctx.user_a),
               Utils.name(ctx.user_b)
             ]

      assert html |> filter_values("activity-filter") |> Enum.map(&elem(&1, 1)) == [
               "Abstract",
               "Essay one",
               "Essay two"
             ]
    end

    test "Apply puts the chosen values in the URL on the first page, keeping the sort and the search",
         ctx do
      {:ok, view, _html} =
        live(ctx.conn, ctx.route <> "?sort_by=user&sort_order=asc&text_search=a&offset=1")

      apply_filter(view, "student-filter", ["#{ctx.user_a.id}"])
      path = assert_patch(view)

      assert %{
               "selected_user_ids" => selected,
               "offset" => "0",
               "sort_by" => "user",
               "sort_order" => "asc",
               "text_search" => "a"
             } = query(path)

      assert Jason.decode!(selected) == [ctx.user_a.id]
      assert row_students(render(view)) == [Utils.name(ctx.user_a), Utils.name(ctx.user_a)]
    end

    test "Activity and Page apply their own lists", ctx do
      {:ok, view, _html} = live(ctx.conn, ctx.route)

      apply_filter(view, "activity-filter", ["#{ctx.act_2.resource.id}"])

      assert Jason.decode!(query(assert_patch(view))["selected_activity_ids"]) == [
               ctx.act_2.resource.id
             ]

      assert row_students(render(view)) == [Utils.name(ctx.user_a)]

      apply_filter(view, "page-filter", ["#{ctx.page1.id}"])
      assert Jason.decode!(query(assert_patch(view))["selected_page_ids"]) == [ctx.page1.id]
    end

    test "Purpose: one value filters by it, on the first page; both or none is no filter", ctx do
      {:ok, view, _html} = live(ctx.conn, ctx.route <> "?sort_by=user&sort_order=asc&offset=1")

      apply_filter(view, "purpose-filter", ["false"])
      path = assert_patch(view)
      assert %{"graded" => "false", "offset" => "0"} = query(path)

      assert row_students(render(view)) == [
               Utils.name(ctx.user_a),
               Utils.name(ctx.user_a),
               Utils.name(ctx.user_b)
             ]

      apply_filter(view, "purpose-filter", ["true"])
      assert query(assert_patch(view))["graded"] == "true"

      apply_filter(view, "purpose-filter", ["true", "false"])
      assert query(assert_patch(view))["graded"] == ""

      apply_filter(view, "purpose-filter", [])
      assert query(assert_patch(view))["graded"] == ""
    end

    test "each filter shows the values the URL applies", ctx do
      {:ok, view, _html} =
        live(ctx.conn, ctx.route <> "?selected_user_ids=[#{ctx.user_a.id}]&graded=false")

      assert view |> element("#student-filter-trigger") |> render() =~
               ~r/1\s*<span[^>]*>\s*selected/

      assert view |> element("#purpose-filter-trigger") |> render() =~
               ~r/1\s*<span[^>]*>\s*selected/

      refute view |> element("#activity-filter-trigger") |> render() =~ "selected"

      view |> element("#student-filter-trigger") |> render_click()

      assert view
             |> element(
               ~s(#student-filter-panel input[type="checkbox"][value="#{ctx.user_a.id}"])
             )
             |> render() =~ "checked"

      view |> element("#purpose-filter-trigger") |> render_click()

      assert view
             |> element(~s(#purpose-filter-panel input[type="checkbox"][value="false"]))
             |> render() =~
               "checked"

      refute view
             |> element(~s(#purpose-filter-panel input[type="checkbox"][value="true"]))
             |> render() =~
               "checked"
    end
  end

  describe "opening a submission from the table" do
    setup [:instructor_conn, :create_queue]

    test "the student name is a full-navigation link to the scoring page, carrying the table params, with an accessible name",
         ctx do
      params = "?selected_user_ids=[#{ctx.user_a.id}]&sort_by=user&sort_order=asc&text_search=Alv"
      {:ok, _view, html} = live(ctx.conn, ctx.route <> params)
      d = Floki.parse_document!(html)

      [link] =
        Floki.find(
          d,
          ~s|tr##{ctx.a_1.id} a[href^="/sections/#{ctx.section.slug}/scoring/#{ctx.a_1.id}"]|
        )

      href = link |> Floki.attribute("href") |> List.first()

      assert query(href) == %{
               "selected_user_ids" => "[#{ctx.user_a.id}]",
               "sort_by" => "user",
               "sort_order" => "asc",
               "text_search" => "Alv"
             }

      assert Floki.attribute(link, "aria-label") == [
               "Score submission: #{Utils.name(ctx.user_a)}, Essay one, attempt 1"
             ]

      assert Floki.attribute(link, "data-phx-link") == []
      assert Floki.attribute(link, "phx-click") == ["[]"]
    end

    test "a legacy filter in the URL reaches the links as its modern equivalent", ctx do
      {:ok, _view, html} = live(ctx.conn, ctx.route <> "?user_id=#{ctx.user_a.id}&sort_by=user")
      d = Floki.parse_document!(html)

      assert row_students(html) == [Utils.name(ctx.user_a), Utils.name(ctx.user_a)]
      [link] = Floki.find(d, ~s|tr##{ctx.a_1.id} a[href]|)
      href = link |> Floki.attribute("href") |> List.first()
      assert query(href) == %{"selected_user_ids" => "[#{ctx.user_a.id}]", "sort_by" => "user"}
    end

    test "an offset past the end of the queue moves to the last page that exists", ctx do
      # Ana's filtered queue has 13 rows (last page at 10); the whole section has 23 (it would be 20).
      Enum.each(1..11, fn _ -> add_attempt(ctx, :ra_a, :act_1, :extra, :submitted) end)
      Enum.each(1..9, fn _ -> add_attempt(ctx, :ra_b, :act_1, :extra, :submitted) end)

      params = "?offset=30&sort_by=user&sort_order=asc&selected_user_ids=[#{ctx.user_a.id}]"
      assert {:error, {:live_redirect, %{to: to}}} = live(ctx.conn, ctx.route <> params)

      assert query(to)["offset"] == "10"
      assert query(to)["selected_user_ids"] == "[#{ctx.user_a.id}]"
      assert query(to)["sort_by"] == "user"
      assert query(to)["sort_order"] == "asc"

      {:ok, _view, html} = live(ctx.conn, to)
      assert row_students(html) == List.duplicate(Utils.name(ctx.user_a), 3)
      refute html =~ "No submissions awaiting scoring."
    end

    test "clicking the row sends the instructor to the same scoring page with one full navigation",
         ctx do
      params = "?selected_user_ids=[#{ctx.user_a.id}]&sort_by=user&sort_order=asc"
      {:ok, view, html} = live(ctx.conn, ctx.route <> params)

      [link] = html |> Floki.parse_document!() |> Floki.find(~s|tr##{ctx.a_2.id} a[href]|)
      href = link |> Floki.attribute("href") |> List.first()

      ref = Process.monitor(view.pid)
      view |> element("tr##{ctx.a_2.id}") |> render_click()
      {to, _flash} = assert_redirect(view)
      assert to == href
      # a full-page redirect, not a push_navigate: the activity scripts must load fresh
      assert_receive {:DOWN, ^ref, :process, _, {:shutdown, {:redirect, %{to: ^href}}}}
    end

    test "a forged row id is ignored", ctx do
      {:ok, view, _html} = live(ctx.conn, ctx.route)

      assert render_hook(view, "paged_table_selection_change", %{"id" => "abc"}) =~
               "manual-scoring-table"

      assert render_hook(view, "paged_table_selection_change", %{"id" => %{"a" => 1}}) =~
               "manual-scoring-table"

      assert_raise ArgumentError, ~r/to redirect, but got none/, fn ->
        assert_redirect(view, 100)
      end
    end

    test "a legacy ?selected=<id> URL redirects to that submission's scoring page with the other params",
         ctx do
      assert {:error, {:redirect, %{to: to}}} =
               live(ctx.conn, ctx.route <> "?selected=#{ctx.a_1.id}&sort_by=user&sort_order=asc")

      assert String.starts_with?(to, "/sections/#{ctx.section.slug}/scoring/#{ctx.a_1.id}")
      assert query(to) == %{"sort_by" => "user", "sort_order" => "asc"}

      {:ok, _view, html} = live(ctx.conn, ctx.route <> "?selected=abc")
      assert html =~ "manual-scoring-table"
    end

    test "the table no longer scores inline: a forged apply is just an unhandled event", ctx do
      {:ok, view, _html} = live(ctx.conn, ctx.route)

      log = capture_log(fn -> render_hook(view, "apply", %{}) end)

      assert log =~ "Unhandled event"
      html = render(view)
      refute html =~ "Enter both a score and feedback"
      refute html =~ "Apply Score and Feedback"
      assert html |> Floki.parse_document!() |> Floki.find("tr[phx-value-id]") |> length() == 3
    end
  end

  describe "filter values with no pending submissions" do
    setup [:instructor_conn, :create_queue]

    test "on a first visit they are removed from the URL by one redirect and named in a notice",
         ctx do
      {:error, {:live_redirect, %{to: to, flash: flash}}} =
        live(ctx.conn, ctx.route <> "?selected_user_ids=[#{ctx.user_c.id},#{ctx.user_a.id}]")

      assert query(to)["selected_user_ids"] == "[#{ctx.user_a.id}]"

      assert flash["info"] ==
               "#{Utils.name(ctx.user_c)} has no more submissions awaiting scoring and was removed from the filter."

      {:ok, _view, html} = live(ctx.conn, to)
      assert row_students(html) == [Utils.name(ctx.user_a), Utils.name(ctx.user_a)]
    end

    test "an id that is not in the section is removed with a generic notice", ctx do
      {:error, {:live_redirect, %{to: to, flash: flash}}} =
        live(ctx.conn, ctx.route <> "?selected_user_ids=[999999]&selected_activity_ids=[999998]")

      assert query(to)["selected_user_ids"] == "[]"
      assert query(to)["selected_activity_ids"] == "[]"

      assert flash["info"] ==
               "A selected student and a selected activity have no more submissions awaiting scoring and were removed from the filter."

      {:ok, _view, html} = live(ctx.conn, to)
      assert length(row_students(html)) == 3
    end

    test "several removed values are named together", ctx do
      {:error, {:live_redirect, %{flash: flash}}} =
        live(
          ctx.conn,
          ctx.route <> "?selected_user_ids=[#{ctx.user_c.id}]&selected_page_ids=[#{ctx.page2.id}]"
        )

      assert flash["info"] ==
               "#{Utils.name(ctx.user_c)} and #{ctx.revision2.title} have no more submissions awaiting scoring and were removed from the filter."
    end

    test "while the table is open, a value that goes out of play is removed by a sort click, once",
         ctx do
      {:ok, view, html} =
        live(ctx.conn, ctx.route <> "?selected_user_ids=[#{ctx.user_a.id},#{ctx.user_b.id}]")

      assert length(row_students(html)) == 3

      Oli.Repo.update!(Ecto.Changeset.change(ctx.b_1, lifecycle_state: :evaluated))

      view |> element(~s(th button[phx-value-sort_by="user"])) |> render_click()
      path = assert_patch(view)

      assert query(path)["selected_user_ids"] == "[#{ctx.user_a.id}]"
      assert query(path)["sort_by"] == "user"

      html = render(view)

      assert html =~
               "#{Utils.name(ctx.user_b)} has no more submissions awaiting scoring and was removed from the filter."

      assert row_students(html) == [Utils.name(ctx.user_a), Utils.name(ctx.user_a)]
      assert_raise ArgumentError, ~r/to patch, but got none/, fn -> assert_patch(view, 100) end
    end

    test "a client patch that only re-adds a stale value still refreshes the 'of M' denominator",
         ctx do
      {:ok, view, html} = live(ctx.conn, ctx.route <> "?selected_user_ids=[#{ctx.user_a.id}]")
      assert html =~ "Showing 2 of 3 submissions"

      Oli.Repo.update!(Ecto.Changeset.change(ctx.b_1, lifecycle_state: :evaluated))

      render_patch(view, ctx.route <> "?selected_user_ids=[#{ctx.user_a.id},#{ctx.user_b.id}]")
      assert_patch(view)
      path = assert_patch(view)
      assert query(path)["selected_user_ids"] == "[#{ctx.user_a.id}]"

      html = render(view)
      assert html =~ "removed from the filter."
      assert html =~ "Showing 2 of 2 submissions"
    end

    test "a stale value arriving by a client patch (browser Back) is removed once and named",
         ctx do
      {:ok, view, _html} =
        live(ctx.conn, ctx.route <> "?selected_user_ids=[#{ctx.user_a.id},#{ctx.user_b.id}]")

      Oli.Repo.update!(Ecto.Changeset.change(ctx.b_1, lifecycle_state: :evaluated))

      render_patch(
        view,
        ctx.route <>
          "?selected_user_ids=[#{ctx.user_a.id},#{ctx.user_b.id}]&sort_by=user&sort_order=asc"
      )

      # the test proxy echoes the requested URL before the server answers
      first = assert_patch(view)
      assert query(first)["selected_user_ids"] == "[#{ctx.user_a.id},#{ctx.user_b.id}]"

      second = assert_patch(view)
      assert query(second)["selected_user_ids"] == "[#{ctx.user_a.id}]"
      assert query(second)["sort_by"] == "user"

      html = render(view)

      assert html =~
               "#{Utils.name(ctx.user_b)} has no more submissions awaiting scoring and was removed from the filter."

      assert row_students(html) == [Utils.name(ctx.user_a), Utils.name(ctx.user_a)]
      assert_raise ArgumentError, ~r/to patch, but got none/, fn -> assert_patch(view, 100) end
    end
  end
end
