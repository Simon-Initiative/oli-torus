defmodule OliWeb.Components.TooltipTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule Fixture do
    use Phoenix.LiveView

    alias OliWeb.Components.Tooltip

    def mount(_params, session, socket) do
      {:ok,
       assign(socket,
         mode: session["mode"] || :tooltip,
         arrow: session["arrow"] || false,
         count: 0
       )}
    end

    def render(assigns) do
      ~H"""
      <Tooltip.render id="help" label="Metric definition" mode={@mode} arrow={@arrow}>
        <:trigger><span>?</span></:trigger>
        <:content>
          <div class="flex flex-col gap-2">
            <strong>Attempt count: {@count}</strong>
            <img src="/example.png" alt="Metric example" />
            <a :if={@mode == :popover} href="/details">Details</a>
            <button :if={@mode == :popover} id="increment" phx-click="increment">Increment</button>
          </div>
        </:content>
      </Tooltip.render>
      <Tooltip.render
        id="custom"
        trigger_id="custom-button"
        label="Custom help"
        class="bg-white text-xs"
        trigger_class="rounded-full"
        position="bottom"
        align="right"
        offset={8}
      >
        <:trigger>?</:trigger>
        <:content>Custom copy</:content>
      </Tooltip.render>
      """
    end

    def handle_event("increment", _params, socket) do
      {:noreply, update(socket, :count, &(&1 + 1))}
    end
  end

  test "renders rich slots with a described trigger and default bubble styling", %{conn: conn} do
    {:ok, view, _} = live_isolated(conn, Fixture)

    assert has_element?(view, "div#help[phx-hook='Popover'][data-tooltip-mode='tooltip']")
    assert has_element?(view, "#help-trigger[aria-describedby='help-content']", "?")

    assert has_element?(
             view,
             "#help-content[hidden][popover='manual'][role='tooltip'] strong",
             "Attempt count: 0"
           )

    assert has_element?(view, "#help-content img[alt='Metric example']")
    assert has_element?(view, "div#help-content[hidden] > div.flex.flex-col.gap-2 strong")
    assert has_element?(view, "#help-content.text-sm.min-w-\\[210px\\]")
    refute has_element?(view, "#help-trigger[aria-expanded]")
    refute has_element?(view, "#help-content a")
    refute has_element?(view, "#help-content [data-tooltip-arrow]")

    assert has_element?(
             view,
             "#custom[data-tooltip-position='bottom'][data-tooltip-align='right'][data-tooltip-offset='8']"
           )

    assert has_element?(view, "#custom-button.rounded-full[aria-describedby='custom-content']")
    assert has_element?(view, "#custom-content.bg-white.text-xs")
    refute has_element?(view, "#custom-content.text-sm")
  end

  test "interactive slots retain LiveView events and update in place", %{conn: conn} do
    {:ok, view, _} = live_isolated(conn, Fixture, session: %{"mode" => :popover, "arrow" => true})

    assert has_element?(
             view,
             "#help-trigger[aria-controls='help-content'][aria-expanded='false'][aria-haspopup='dialog'][popovertarget='help-content']"
           )

    refute has_element?(view, "#help-trigger[aria-describedby]")

    assert has_element?(
             view,
             "#help-content[popover='auto'][role='dialog'][aria-label='Metric definition'] a[href='/details']"
           )

    view |> element("#increment") |> render_click()

    assert has_element?(view, "#help-content strong", "Attempt count: 1")
    assert has_element?(view, "#help-content img[alt='Metric example']")
    assert has_element?(view, "#help-content [data-tooltip-body].text-sm")
    assert has_element?(view, "#help-content [data-tooltip-arrow][aria-hidden='true'] svg")
    refute has_element?(view, "#help-content.text-sm")
  end

  test "tooltip mode can opt in to an arrow without changing the accessible description", %{
    conn: conn
  } do
    {:ok, view, _} = live_isolated(conn, Fixture, session: %{"arrow" => true})

    assert has_element?(view, "#help-trigger[aria-describedby='help-content']")

    assert has_element?(
             view,
             "#help-content[role='tooltip'] [data-tooltip-body] strong",
             "Attempt count: 0"
           )

    assert has_element?(view, "#help-content [data-tooltip-arrow][aria-hidden='true']")
    refute has_element?(view, "#custom [data-tooltip-arrow]")
  end
end
