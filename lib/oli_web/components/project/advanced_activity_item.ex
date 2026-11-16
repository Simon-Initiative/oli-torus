defmodule OliWeb.Components.Project.AdvancedActivityItem do
  use OliWeb, :live_component

  attr :activity, :map, required: true
  attr :project_id, :integer, required: true
  attr :author, :map, required: true, doc: "the author changing the project's activities"

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
          phx-value-project_id={@project_id}
          phx-value-activity_id={@activity.id}
          phx-value-status={@activity.project_status}
          phx-value-title={@activity.title}
          phx-target={@myself}
          class="btn justify-start text-[#0165da] text-base font-medium"
        >
          {if @activity.project_status == :enabled, do: "Disable", else: "Enable"}
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
    case set_status(socket, project_id, activity_id, :disabled) do
      :ok ->
        send(self(), {:flash_message, {:info, "Activity `#{title}` disabled successfully."}})

        {:noreply,
         assign(socket, activity: %{socket.assigns.activity | project_status: :disabled})}

      {:error, reason} ->
        send(self(), {:flash_message, {:error, error_message(reason)}})

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
    case set_status(socket, project_id, activity_id, :enabled) do
      :ok ->
        send(self(), {:flash_message, {:info, "Activity `#{title}` enabled successfully."}})

        {:noreply,
         assign(socket, activity: %{socket.assigns.activity | project_status: :enabled})}

      {:error, reason} ->
        send(self(), {:flash_message, {:error, error_message(reason)}})

        {:noreply, socket}
    end
  end

  # The IDs arrive as strings from the page.
  defp set_status(socket, project_id, activity_id, status) do
    Oli.Activities.Audited.set_project_activity_status(
      Oli.Auditing.Context.for_actor(socket.assigns.author, source: :ui),
      to_integer(project_id),
      to_integer(activity_id),
      status
    )
  end

  defp to_integer(id) when is_integer(id), do: id
  defp to_integer(id) when is_binary(id), do: String.to_integer(id)

  defp error_message(message) when is_binary(message), do: message
  defp error_message(_reason), do: "The activity could not be updated."
end
