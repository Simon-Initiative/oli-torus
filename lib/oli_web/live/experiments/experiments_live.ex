defmodule OliWeb.Experiments.ExperimentsView do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, :live}

  import Oli.Utils, only: [uuid: 0]
  import OliWeb.Components.Common

  alias Oli.Resources.ResourceType
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Resources.Revision

  @title "Experiments"
  @alternatives_type_id ResourceType.id_for_alternatives()

  def mount(_params, _session, socket) do
    experiment = ResourceEditor.get_experiment(socket.assigns.project.slug)

    socket = assign(socket, is_upgrade_enabled: false)
    socket = assign(socket, title: @title)
    socket = assign(socket, experiment: experiment)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-y-6 ml-8 mt-4">
      <h3>A/B Testing with UpGrade</h3>
      <p>
        To support A/B testing, Torus integrates with the A/B testing platform,
        <a
          class="underline text-inherit decoration-grey-500/30"
          href="https://upgrade.oli.cmu.edu/login"
        >
          UpGrade
        </a>
      </p>
      <.input
        type="checkbox"
        class="form-check-input"
        name="experiments"
        value={nil}
        label="Enable A/B testing with UpGrade"
        phx-click="enable_upgrade"
        checked={@is_upgrade_enabled}
      />

      <%= if @experiment do %>
        <OliWeb.Resources.AlternativesEditor.group
          group={@experiment}
          editing_enabled={@is_upgrade_enabled}
          source={:experiments}
        />
      <% end %>
    </div>
    """
  end

  def handle_event("enable_upgrade", params, socket) do
    socket =
      case socket.assigns.experiment do
        nil ->
          {:ok, experiment} =
            create_experiment(socket.assigns.project, socket.assigns.current_author)

          assign(socket, experiment: experiment, is_upgrade_enabled: true)

        %Revision{} ->
          if Map.get(params, "value") do
            assign(socket, :is_upgrade_enabled, true)
          else
            assign(socket, :is_upgrade_enabled, false)
          end
      end

    {:noreply, socket}
  end

  defp create_experiment(project, author) do
    initial_opts = [
      %{"id" => uuid(), "name" => "Option 1"},
      %{"id" => uuid(), "name" => "Option 2"}
    ]

    attrs = %{
      title: "Decision Point",
      content: %{"options" => initial_opts, "strategy" => "upgrade_decision_point"}
    }

    ResourceEditor.create(project.slug, author, @alternatives_type_id, attrs)
  end
end
