defmodule OliWeb.Components.Filters.CheckboxFilterTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Filters.CheckboxFilter

  defmodule Host do
    use Phoenix.LiveView

    alias OliWeb.Components.Filters.CheckboxFilter

    def mount(_params, session, socket) do
      {:ok,
       assign(socket,
         test_pid: session["test_pid"],
         options: session["options"],
         selected: session["selected"],
         searchable: session["searchable"],
         max_selected: session["max_selected"]
       )}
    end

    def render(assigns) do
      ~H"""
      <.live_component
        module={CheckboxFilter}
        id="student-filter"
        label="Student"
        options={@options}
        selected_ids={@selected}
        searchable={@searchable}
        on_apply={:user_ids}
        max_selected={@max_selected}
      />
      """
    end

    def handle_info({:filter_applied, key, ids}, socket) do
      send(socket.assigns.test_pid, {:applied, key, ids})
      {:noreply, assign(socket, selected: ids)}
    end

    def handle_info({:filter_limit_reached, key, max}, socket) do
      send(socket.assigns.test_pid, {:limit_reached, key, max})
      {:noreply, socket}
    end

    def handle_info({:parent_update, selected}, socket),
      do: {:noreply, assign(socket, selected: selected)}
  end

  @options [
    %{id: 1, label: "Adams, Amy"},
    %{id: 2, label: "Baker, Beth"},
    %{id: 3, label: "Clark, Cleo"}
  ]

  defp mount_filter(conn, selected, searchable \\ true, max_selected \\ nil) do
    {:ok, view, _html} =
      live_isolated(conn, Host,
        session: %{
          "test_pid" => self(),
          "options" => @options,
          "selected" => selected,
          "searchable" => searchable,
          "max_selected" => max_selected
        }
      )

    view
  end

  defp open(view), do: view |> element("#student-filter-trigger") |> render_click()
  defp form(view), do: element(view, "#student-filter-form")

  defp change(view, params),
    do: render_change(form(view), Map.put(params, "_target", ["selected"]))

  defp open?(view) do
    view |> element("#student-filter-trigger") |> render() =~ ~s(aria-expanded="true") and
      not (view |> element("#student-filter-panel") |> render() =~ ~r/^<div[^>]*hidden/)
  end

  defp checked(view) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.find(~s(#student-filter-panel input[type="checkbox"][checked]))
    |> Enum.flat_map(&Floki.attribute(&1, "value"))
  end

  defp box_markup(view) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.find(~s(#student-filter-panel input[type="checkbox"]))
    |> Map.new(&{hd(Floki.attribute(&1, "value")), Floki.raw_html(&1)})
  end

  defp click_away_event(view) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.attribute("#student-filter", "phx-click-away")
    |> hd()
    |> Jason.decode!()
  end

  test "checking or unchecking a box sends the checked options to the parent at once and keeps the panel open",
       %{conn: conn} do
    view = mount_filter(conn, [1])
    refute open?(view)

    open(view)
    assert open?(view)
    assert checked(view) == ["1"]

    change(view, %{"selected" => ["1", "2"]})
    assert_receive {:applied, :user_ids, [1, 2]}
    assert open?(view)
    assert checked(view) == ["1", "2"]

    assert view |> element("#student-filter-trigger") |> render() =~
             ~r/2\s*<span[^>]*>\s*selected/

    change(view, %{"selected" => ["2"]})
    assert_receive {:applied, :user_ids, [2]}

    change(view, %{"selected" => []})
    assert_receive {:applied, :user_ids, []}
    assert open?(view)
  end

  test "the panel has no Apply or Cancel: Escape, a click outside and the trigger only close it",
       %{conn: conn} do
    view = mount_filter(conn, [1])
    open(view)

    refute has_element?(view, "#student-filter-apply")
    refute has_element?(view, "#student-filter-cancel")

    view |> element("#student-filter") |> render_keydown(%{"key" => "Escape"})
    refute open?(view)

    open(view)
    assert [["push", %{"event" => "close"}]] = click_away_event(view)
    view |> with_target("#student-filter") |> render_hook("close", %{})
    refute open?(view)

    open(view)
    open(view)
    refute open?(view)

    refute_received {:applied, _, _}
  end

  test "a search change or Enter in the search applies nothing and keeps the panel open",
       %{conn: conn} do
    view = mount_filter(conn, [1])
    open(view)

    render_change(form(view), %{
      "_target" => ["query"],
      "query" => "bet",
      "selected" => ["1", "2"]
    })

    assert view |> element("#student-filter-search") |> render() =~ ~s(value="bet")

    render_submit(form(view), %{"query" => "cla", "selected" => ["1", "3"]})
    assert view |> element("#student-filter-search") |> render() =~ ~s(value="cla")

    assert open?(view)
    assert checked(view) == ["1"]
    refute_received {:applied, _, _}
  end

  test "the search starts empty each time the panel opens, even after a late search change",
       %{conn: conn} do
    view = mount_filter(conn, [])
    open(view)
    render_change(form(view), %{"_target" => ["query"], "query" => "bet"})
    view |> element("#student-filter") |> render_keydown(%{"key" => "Escape"})
    render_change(form(view), %{"_target" => ["query"], "query" => "cla"})

    open(view)

    assert view |> element("#student-filter-search") |> render() =~ ~s(value="")
  end

  test "the search hides options that do not match, ignoring case, and a checked hidden one stays applied",
       %{conn: conn} do
    view = mount_filter(conn, [2])
    open(view)

    render_change(form(view), %{"_target" => ["query"], "query" => "ADA", "selected" => ["2"]})

    assert view |> element("#student-filter-option-1") |> render() =~ ~r/^<div(?![^>]*hidden)/
    assert view |> element("#student-filter-option-2") |> render() =~ ~r/^<div[^>]*hidden/
    assert view |> element("#student-filter-option-3") |> render() =~ ~r/^<div[^>]*hidden/
    assert checked(view) == ["2"]

    change(view, %{"query" => "ADA", "selected" => ["1", "2"]})
    assert_receive {:applied, :user_ids, [1, 2]}
    assert view |> element("#student-filter-search") |> render() =~ ~s(value="ADA")
  end

  test "the boxes show the parent's values, open or closed", %{conn: conn} do
    view = mount_filter(conn, [1])
    open(view)

    send(view.pid, {:parent_update, [3]})
    assert checked(view) == ["3"]
    assert open?(view)

    view |> element("#student-filter") |> render_keydown(%{"key" => "Escape"})
    send(view.pid, {:parent_update, [2]})
    open(view)
    assert checked(view) == ["2"]
  end

  test "closed, the panel holds no options; they render when it opens", %{conn: conn} do
    view = mount_filter(conn, [1])

    refute has_element?(view, ~s(#student-filter-panel input[type="checkbox"]))

    open(view)
    assert has_element?(view, ~s(#student-filter-panel input[type="checkbox"][value="3"]))
  end

  test "a value sent back to the parent is the option's own id, not its form string",
       %{conn: conn} do
    view = mount_filter(conn, [])
    open(view)

    change(view, %{"selected" => ["3", "999", "x"]})
    assert_receive {:applied, :user_ids, [3]}
  end

  test "a search value that is not text counts as no search and never breaks the page",
       %{conn: conn} do
    view = mount_filter(conn, [])
    open(view)

    for forged <- [%{"x" => "y"}, ["Amy"]] do
      render_change(form(view), %{"_target" => ["query"], "query" => forged})

      assert open?(view)

      for id <- [1, 2, 3] do
        assert view |> element("#student-filter-option-#{id}") |> render() =~
                 ~r/^<div(?![^>]*hidden)/
      end
    end
  end

  test "a recovered form that was open reopens the panel with its search and applies nothing" do
    closed = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        options: @options,
        selected_ids: [1],
        on_apply: :user_ids,
        open: false,
        query: ""
      }
    }

    {:noreply, recovered} =
      CheckboxFilter.handle_event(
        "recover",
        %{"open" => "true", "query" => "bet", "selected" => ["2"]},
        closed
      )

    assert %{open: true, query: "bet", selected_ids: [1]} = recovered.assigns
    refute_received {:filter_applied, _, _}

    {:noreply, still_closed} =
      CheckboxFilter.handle_event("recover", %{"query" => "", "selected" => []}, closed)

    assert %{open: false} = still_closed.assigns
  end

  test "only an open filter's form says it is open, so a reconnect reopens only that one",
       %{conn: conn} do
    view = mount_filter(conn, [])
    refute has_element?(view, ~s(#student-filter-form input[name="open"]))

    open(view)

    assert has_element?(
             view,
             ~s(#student-filter-form input[type="hidden"][name="open"][value="true"])
           )
  end

  test "a late search change after the panel closed does not reopen it or apply anything",
       %{conn: conn} do
    view = mount_filter(conn, [1])
    open(view)
    view |> element("#student-filter") |> render_keydown(%{"key" => "Escape"})

    render_change(form(view), %{
      "_target" => ["query"],
      "open" => "true",
      "query" => "bet",
      "selected" => ["2"]
    })

    refute open?(view)
    refute_received {:applied, _, _}
    open(view)
    assert checked(view) == ["1"]
  end

  describe "with max_selected" do
    test "a change within the limit applies", %{conn: conn} do
      view = mount_filter(conn, [1], true, 2)
      open(view)

      change(view, %{"selected" => ["1", "2"]})
      assert_receive {:applied, :user_ids, [1, 2]}
    end

    test "a change past the limit applies nothing, tells the parent, and re-renders every box so the browser drops the refused check",
         %{conn: conn} do
      view = mount_filter(conn, [1, 2], true, 2)
      open(view)
      before = box_markup(view)

      change(view, %{"selected" => ["1", "2", "3"]})

      assert_receive {:limit_reached, :user_ids, 2}
      refute_received {:applied, _, _}
      assert checked(view) == ["1", "2"]
      assert open?(view)

      after_refusal = box_markup(view)

      for {id, markup} <- before do
        refute after_refusal[id] == markup, "box #{id} was not re-rendered"
      end
    end
  end

  test "without search, the panel has no search box", %{conn: conn} do
    view = mount_filter(conn, [], false)
    open(view)

    refute has_element?(view, "#student-filter-search")
    assert has_element?(view, ~s(#student-filter-panel input[type="checkbox"][value="1"]))
  end
end
