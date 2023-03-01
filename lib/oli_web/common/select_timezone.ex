defmodule OliWeb.Common.SelectTimezone do
  use Phoenix.Component

  import Phoenix.HTML.Form

  alias Oli.Predefined
  alias OliWeb.Common.{FormatDateTime, SessionContext}
  alias OliWeb.Router.Helpers, as: Routes

  attr :context, SessionContext

  def render(assigns) do
    assigns = timezone_assigns(assigns)

    ~H"""
      <script>
        function submitForm(){
          const relativePath = window.location.pathname+window.location.search;
          $('#hidden-redirect-to').val(relativePath);
          $('#timezone-form').submit()
        }
      </script>

      <%= form_for :timezone, Routes.static_page_path(OliWeb.Endpoint, :update_timezone), [id: "timezone-form"], fn f -> %>
        <%= hidden_input f, :redirect_to, id: "hidden-redirect-to" %>
        <div class="form-label-group">
          <%= select f, :timezone, @timezones, onchange: "submitForm()", selected: selected_timezone(@browser_timezone), class: "form-control dropdown-select", required: true %>
        </div>
      <% end %>
    """
  end

  def timezone_assigns(assigns) do
    default_timezone = FormatDateTime.default_timezone()

    browser_timezone =
      case assigns do
        %{context: %{local_tz: local_tz}} ->
          local_tz

        _ ->
          default_timezone
      end

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

    assigns
    |> assign(:default_timezone, default_timezone)
    |> assign(:browser_timezone, browser_timezone)
    |> assign(:timezones, timezones)
  end

  defp selected_timezone(browser_timezone) do
    default = FormatDateTime.default_timezone()

    case browser_timezone do
      ^default -> "Etc/Greenwich"
      timezone -> timezone
    end
  end
end
