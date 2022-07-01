defmodule OliWeb.Common.SelectTimezone do
  use Phoenix.Component

  import Phoenix.HTML.Form

  alias Oli.Predefined
  alias OliWeb.Common.{FormatDateTime, SessionContext}
  alias OliWeb.Router.Helpers, as: Routes

  def render(%{conn: conn} = assigns) do
    browser_timezone = Plug.Conn.get_session(conn, "browser_timezone")
    context = SessionContext.init(conn)

    timezones =
      Enum.map(Predefined.timezones(), fn
        {timezone_desc, ^browser_timezone} ->
          [
            key: timezone_desc <> " (browser default)",
            value: browser_timezone,
            class: "font-weight-bold"
          ]

        {timezone_desc, timezone} ->
          [key: timezone_desc, value: timezone]
      end)

    ~H"""
      <script>
        function submitForm(){
          const relativePath = window.location.pathname+window.location.search;
          $('#hidden-redirect-to').val(relativePath);
          $('#timezone-form').submit()
        }
      </script>

      <%= form_for @conn, Routes.static_page_path(@conn, :update_timezone), [id: "timezone-form"], fn f -> %>
        <%= hidden_input f, :redirect_to, id: "hidden-redirect-to" %>
        <div class="form-label-group">
          <%= select f, :timezone, timezones, onchange: "submitForm()", selected: selected_timezone(context.local_tz), class: "form-control dropdown-select", required: true %>
        </div>
      <% end %>
    """
  end

  defp selected_timezone(timezone) do
    default = FormatDateTime.default_timezone()

    case timezone do
      ^default -> "Etc/Greenwich"
      timezone -> timezone
    end
  end
end
