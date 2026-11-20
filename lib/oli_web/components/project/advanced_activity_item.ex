defmodule OliWeb.Components.Project.AdvancedActivityItem do
  use OliWeb, :live_component

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Activities

  attr :activity, :map, required: true
  attr :project, :map, required: true
  attr :current_author, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="flex flex-row py-3 border-b last:border-b-0">
      <div class="flex flex-1 flex-col justify-center">
        <div>{@activity.title}</div>
        <span :if={@activity.deployment_id} class="text-sm text-[#737373]">
          Deployment Id: {@activity.deployment_id}
        </span>
      </div>

      <div class="user-actions">
        <button
          phx-click="toggle_activity"
          phx-target={@myself}
          class="btn justify-start text-[#0165da] text-base font-medium"
        >
          {if @activity.project_status == :enabled, do: "Disable", else: "Enable"}
        </button>
      </div>
    </div>
    """
  end

  def handle_event("toggle_activity", _params, socket) do
    %{activity: activity, project: project, current_author: current_author} = socket.assigns

    with %Author{} = author <- Accounts.get_author(current_author.id),
         true <- Accounts.can_access?(author, project) do
      toggle(socket, activity, project)
    else
      _ ->
        send(self(), {:flash_message, {:error, "You don't have access to this project."}})
        {:noreply, socket}
    end
  end

  defp toggle(socket, %{project_status: :enabled} = activity, project) do
    case Activities.disable_activity_in_project(project.id, activity.id) do
      :ok ->
        send(
          self(),
          {:flash_message, {:info, "Activity `#{activity.title}` disabled successfully."}}
        )

        {:noreply, assign(socket, activity: %{activity | project_status: :disabled})}

      {:error, message} ->
        send(self(), {:flash_message, {:error, message}})
        {:noreply, socket}
    end
  end

  defp toggle(socket, %{project_status: :disabled} = activity, project) do
    case Activities.enable_activity_in_project(project.id, activity.id) do
      :ok ->
        send(
          self(),
          {:flash_message, {:info, "Activity `#{activity.title}` enabled successfully."}}
        )

        {:noreply, assign(socket, activity: %{activity | project_status: :enabled})}

      {:error, message} ->
        send(self(), {:flash_message, {:error, message}})
        {:noreply, socket}
    end
  end
end
