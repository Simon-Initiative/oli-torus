defmodule OliWeb.Components.Project.AdvancedActivityItem do
  use OliWeb, :live_component

  alias Oli.Activities

  attr :activity, :map, required: true
  attr :project_id, :integer, required: true

  def render(assigns) do
    ~H"""
    <div class="flex flex-row py-3 border-b last:border-b-0">
      <div class="flex flex-1 flex-col justify-center">
        <div><%= @activity.title %></div>
        <span :if={@activity.deployment_id} class="text-sm text-[#737373]">
          Deployment Id: <%= @activity.deployment_id %>
        </span>
      </div>

      <div class="user-actions">
        <button
          phx-click="toggle_activity"
          phx-value-project_id={@project_id}
          phx-value-activity_id={@activity.id}
          phx-value-status={@activity.project_status}
          phx-value-title={@activity.title}
          phx-target={@myself}
          class="btn justify-start text-[#0165da] text-base font-medium"
        >
          <%= if @activity.project_status == :enabled, do: "Disable", else: "Enable" %>
        </button>
      </div>
    </div>
    """
  end

  def handle_event(
        "toggle_activity",
        %{
          "project_id" => project_id,
          "activity_id" => activity_id,
          "status" => "enabled",
          "title" => title
        },
        socket
      ) do
    case Activities.disable_activity_in_project(project_id, activity_id) do
      :ok ->
        send(self(), {:flash_message, {:info, "Activity `#{title}` disabled successfully."}})

        {:noreply,
         assign(socket, activity: %{socket.assigns.activity | project_status: :disabled})}

      {:error, message} ->
        send(self(), {:flash_message, {:error, message}})

        {:noreply, socket}
    end
  end

  def handle_event(
        "toggle_activity",
        %{
          "project_id" => project_id,
          "activity_id" => activity_id,
          "status" => "disabled",
          "title" => title
        },
        socket
      ) do
    case Activities.enable_activity_in_project(project_id, activity_id) do
      :ok ->
        send(self(), {:flash_message, {:info, "Activity `#{title}` enabled successfully."}})

        {:noreply,
         assign(socket, activity: %{socket.assigns.activity | project_status: :enabled})}

      {:error, message} ->
        send(self(), {:flash_message, {:error, message}})

        {:noreply, socket}
    end
  end
end
