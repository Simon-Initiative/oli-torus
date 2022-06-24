defmodule OliWeb.Common.SelectTimezone do
  use Phoenix.Component

  import Phoenix.HTML.Form

  alias Oli.Predefined
  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do
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
          <%= select f, :timezone, Predefined.timezones(), onchange: "submitForm()", selected: @selected || "Etc/Greenwich", class: "form-control dropdown-select", required: true %>
        </div>
      <% end %>
    """
  end
end
