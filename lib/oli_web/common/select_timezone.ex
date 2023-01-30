defmodule OliWeb.Common.SelectTimezone do
  use Phoenix.Component

  import Phoenix.HTML.Form

  alias Oli.Predefined
  alias OliWeb.Common.{FormatDateTime, SessionContext}
  alias OliWeb.Router.Helpers, as: Routes

  def render(%{conn: conn} = assigns) do
    browser_timezone = Plug.Conn.get_session(conn, "browser_timezone")
    context = SessionContext.init(conn)

    {maybe_browser_timezone, timezones} =
      Enum.split_with(Predefined.timezones(), fn
        {_, ^browser_timezone} -> true
        _ -> false
      end)

    timezones =
      case maybe_browser_timezone do
        [{timezone_desc, browser_timezone}] ->
          [
            {"Use Browser Timezone - " <> timezone_desc, browser_timezone}
            | timezones
          ]

        [] ->
          timezones
      end

    assigns = assign(assigns, :timezones, timezones)
    |> assign(:context, context)

    ~H"""
      <script>
        function submitForm(){
          const relativePath = window.location.pathname+window.location.search;
          $('#hidden-redirect-to').val(relativePath);
          $('#timezone-form').submit()
        }
      </script>

      <%= form_for @conn, Routes.static_page_path(OliWeb.Endpoint, :update_timezone), [id: "timezone-form"], fn f -> %>
        <%= hidden_input f, :redirect_to, id: "hidden-redirect-to" %>
        <div class="form-label-group">
          <%= select f, :timezone, @timezones, onchange: "submitForm()", selected: selected_timezone(@context.local_tz), class: "form-control dropdown-select", required: true %>
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
