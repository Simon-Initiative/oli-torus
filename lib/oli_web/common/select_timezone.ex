defmodule OliWeb.Common.SelectTimezone do
  use Phoenix.Component

  alias OliWeb.Common.{FormatDateTime, SessionContext}
  alias OliWeb.Router.Helpers, as: Routes

  attr(:ctx, SessionContext)

  def render(assigns) do
    assigns = timezone_assigns(assigns)

    ~H"""
    <div id="select-timezone" phx-update="ignore">
      <%= ReactPhoenix.ClientSide.react_component("Components.SelectTimezone", %{
        selectedTimezone: @selected_timezone,
        timezones: @timezones,
        submitAction: Routes.static_page_path(OliWeb.Endpoint, :update_timezone)
      }) %>
    </div>
    """
  end

  def timezone_assigns(assigns) do
    # we always offer the option to "use browser timezone".
    # if the browser timezone is not available, we use the server default timezone.
    browser_timezone = assigns.ctx.browser_timezone || FormatDateTime.default_timezone()

    timezones =
      [
        {"Use Browser Timezone (#{browser_timezone})", "browser"}
        | Enum.map(Tzdata.zone_list(), fn tz ->
            {tz, tz}
          end)
      ]
      |> Enum.map(&Tuple.to_list/1)

    selected_timezone =
      case assigns do
        %{ctx: %{local_tz: local_tz}} ->
          local_tz

        _ ->
          nil
      end

    assigns
    |> assign(:selected_timezone, selected_timezone)
    |> assign(:timezones, timezones)
  end
end
