defmodule OliWeb.Common.SelectTimezone do
  use Phoenix.Component

  import Phoenix.HTML.Form

  alias Oli.Predefined
  alias OliWeb.Common.SessionContext
  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do
    context = SessionContext.init(assigns.conn)
    browser_timezone = Plug.Conn.get_session(assigns.conn, "local_tz")

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
          <%= select f, :timezone, timezones, onchange: "submitForm()", selected: context.local_tz || "Etc/Greenwich", class: "form-control dropdown-select", required: true %>
        </div>
      <% end %>
    """
  end
end
