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
         searchable: session["searchable"]
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
      />
      """
    end

    def handle_info({:filter_applied, key, ids}, socket) do
      send(socket.assigns.test_pid, {:applied, key, ids})
      {:noreply, assign(socket, selected: ids)}
    end

    def handle_info({:parent_update, selected}, socket),
      do: {:noreply, assign(socket, selected: selected)}
  end

  @options [
    %{id: 1, label: "Alvarez, Ana"},
    %{id: 2, label: "Bermudez, Bea"},
    %{id: 3, label: "Cruz, Cata"}
  ]

  defp mount_filter(conn, selected, searchable \\ true) do
    {:ok, view, _html} =
      live_isolated(conn, Host,
        session: %{
          "test_pid" => self(),
          "options" => @options,
          "selected" => selected,
          "searchable" => searchable
        }
      )

    view
  end

  defp open(view), do: view |> element("#student-filter-trigger") |> render_click()
  defp form(view), do: element(view, "#student-filter-form")

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

  test "opening starts the draft from the applied values; Apply sends the draft and closes",
       %{conn: conn} do
    view = mount_filter(conn, [1])
    refute open?(view)

    open(view)
    assert open?(view)
    assert checked(view) == ["1"]

    render_change(form(view), %{"selected" => ["1", "2"]})
    assert checked(view) == ["1", "2"]
    refute_received {:applied, _, _}

    render_submit(form(view), %{"selected" => ["1", "2"]})
    assert_receive {:applied, :user_ids, [1, 2]}
    refute open?(view)

    assert view |> element("#student-filter-trigger") |> render() =~
             ~r/2\s*<span[^>]*>\s*selected/
  end

  test "Cancel and Escape close without applying and discard the draft and the search",
       %{conn: conn} do
    view = mount_filter(conn, [1])

    open(view)
    render_change(form(view), %{"query" => "bea", "selected" => ["1", "2"]})
    view |> element("#student-filter-cancel") |> render_click()

    refute open?(view)
    refute_received {:applied, _, _}

    open(view)
    assert checked(view) == ["1"]
    assert view |> element("#student-filter-search") |> render() =~ ~s(value="")

    render_change(form(view), %{"selected" => ["3"]})
    view |> element("#student-filter") |> render_keydown(%{"key" => "Escape"})

    refute open?(view)
    open(view)
    assert checked(view) == ["1"]
    refute_received {:applied, _, _}
  end

  test "the search hides options that do not match, ignoring case, and keeps checked hidden ones",
       %{conn: conn} do
    view = mount_filter(conn, [2])
    open(view)

    render_change(form(view), %{"query" => "ALV", "selected" => ["2"]})

    assert view |> element("#student-filter-option-1") |> render() =~ ~r/^<div(?![^>]*hidden)/
    assert view |> element("#student-filter-option-2") |> render() =~ ~r/^<div[^>]*hidden/
    assert view |> element("#student-filter-option-3") |> render() =~ ~r/^<div[^>]*hidden/
    assert checked(view) == ["2"]

    render_submit(form(view), %{"query" => "ALV", "selected" => ["1", "2"]})
    assert_receive {:applied, :user_ids, [1, 2]}
  end

  test "while open, a parent update keeps the draft; once closed, the filter shows the parent's values",
       %{conn: conn} do
    view = mount_filter(conn, [1])
    open(view)
    render_change(form(view), %{"selected" => ["1", "2"]})

    send(view.pid, {:parent_update, [3]})
    assert checked(view) == ["1", "2"]
    assert open?(view)

    view |> element("#student-filter-cancel") |> render_click()
    open(view)
    assert checked(view) == ["3"]
  end

  test "a value sent back to the parent is the option's own id, not its form string",
       %{conn: conn} do
    view = mount_filter(conn, [])
    open(view)

    render_submit(form(view), %{"selected" => ["3", "999", "x"]})
    assert_receive {:applied, :user_ids, [3]}
  end

  test "a search value that is not text counts as no search and never breaks the page",
       %{conn: conn} do
    view = mount_filter(conn, [])
    open(view)

    for forged <- [%{"x" => "y"}, ["Ana"]] do
      render_change(form(view), %{"query" => forged})

      assert open?(view)

      for id <- [1, 2, 3] do
        assert view |> element("#student-filter-option-#{id}") |> render() =~
                 ~r/^<div(?![^>]*hidden)/
      end
    end
  end

  test "a recovered form that was open reopens the panel with its draft and search" do
    closed = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        options: @options,
        selected_ids: [1],
        open: false,
        draft: [],
        query: ""
      }
    }

    {:noreply, recovered} =
      CheckboxFilter.handle_event(
        "recover",
        %{"open" => "true", "query" => "bea", "selected" => ["2"]},
        closed
      )

    assert %{open: true, draft: [2], query: "bea"} = recovered.assigns

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

  test "a search change leaves the checked choices alone; a checkbox change replaces them, even with none left" do
    open_with_draft = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        options: @options,
        selected_ids: [1],
        open: true,
        draft: [2],
        query: ""
      }
    }

    {:noreply, searched} =
      CheckboxFilter.handle_event(
        "change",
        %{"_target" => ["query"], "query" => "a", "open" => "true"},
        open_with_draft
      )

    assert %{draft: [2], query: "a"} = searched.assigns

    {:noreply, unchecked} =
      CheckboxFilter.handle_event(
        "change",
        %{"_target" => ["selected"], "query" => "a", "open" => "true"},
        open_with_draft
      )

    assert %{draft: [], query: "a"} = unchecked.assigns
  end

  test "a late change event after the panel closed does not reopen it", %{conn: conn} do
    view = mount_filter(conn, [1])
    open(view)
    view |> element("#student-filter-cancel") |> render_click()

    render_change(form(view), %{
      "_target" => ["query"],
      "open" => "true",
      "query" => "bea",
      "selected" => ["2"]
    })

    refute open?(view)
    open(view)
    assert checked(view) == ["1"]
  end

  test "without search, the panel has no search box", %{conn: conn} do
    view = mount_filter(conn, [], false)
    open(view)

    refute has_element?(view, "#student-filter-search")
    assert has_element?(view, ~s(#student-filter-panel input[type="checkbox"][value="1"]))
  end
end
