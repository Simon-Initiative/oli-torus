defmodule OliWeb.Common.SelectTimezone do
  use Phoenix.Component

  import Phoenix.HTML.Form

  alias Oli.Predefined
  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~H"""
      <%= form_for @conn, Routes.static_page_path(@conn, :update_timezone), fn f -> %>
        <%= hidden_input f, :redirect_to, value: @conn.request_path %>
        <div class="form-label-group">
          <%= select f, :timezone, Predefined.timezones(), onchange: "this.form.submit()", selected: @selected || "Etc/Greenwich", prompt: "Select Timezone", class: "form-control dropdown-select", required: true %>
        </div>
      <% end %>
    """
  end
end
