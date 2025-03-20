defmodule OliWeb.Components.Delivery.LTIExternalTools do
  use Phoenix.Component

  attr :name, :string, required: true
  attr :login_url, :string, required: true
  attr :launch_params, :map, required: true

  def lti_external_tool(assigns) do
    ~H"""
    <div class="mt-3" style="height: 600px">
      <form action={@login_url} class="hide" method="POST" target="tool-content">
        <%= for key <- @launch_params |> Map.keys do %>
          <input type="hidden" name={key} value={@launch_params[key]} />
        <% end %>

        <div style="margin-bottom: 20px;">
          <button class="btn btn-primary" type="submit">
            Launch <%= @name %>
          </button>
        </div>
      </form>
      <iframe
        src="about:blank"
        name="tool-content"
        class="tool_launch"
        allowfullscreen="allowfullscreen"
        webkitallowfullscreen="true"
        mozallowfullscreen="true"
        tabindex="0"
        title="Tool Content"
        style="height:100%;width:100%;"
        allow="geolocation *; microphone *; camera *; midi *; encrypted-media *; autoplay *"
        data-lti-launch="true"
      >
      </iframe>
    </div>
    """
  end
end
