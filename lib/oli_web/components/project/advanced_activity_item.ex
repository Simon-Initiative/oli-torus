defmodule OliWeb.Components.Project.AdvancedActivityItem do
  use Phoenix.Component
  use OliWeb, :verified_routes

  attr :activity_enabled, :map, required: true
  attr :project, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="flex flex-row py-3 border-b last:border-b-0">
      <div class="flex flex-1 flex-col">
        <div><%= @activity_enabled.title %></div>
        <span :if={@activity_enabled.deployment_id} class="text-sm text-[#737373]">
          Deployment Id: <%= @activity_enabled.deployment_id %>
        </span>
      </div>

      <div class="user-actions">
        <%= if @activity_enabled.global do %>
          ---
        <% else %>
          <.link
            href={
              if @activity_enabled.enabled,
                do:
                  ~p"/authoring/project/#{@project.slug}/activities/disable/#{@activity_enabled.slug}",
                else:
                  ~p"/authoring/project/#{@project.slug}/activities/enable/#{@activity_enabled.slug}"
            }
            method="put"
            class="btn justify-start text-[#0165da] text-base font-medium"
          >
            <%= if @activity_enabled.enabled, do: "Disable", else: "Enable" %>
          </.link>
        <% end %>
      </div>
    </div>
    """
  end
end
