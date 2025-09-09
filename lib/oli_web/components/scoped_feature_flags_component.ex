defmodule OliWeb.Components.ScopedFeatureFlagsComponent do
  @moduledoc """
  A reusable LiveView component for managing scoped feature flags.

  This component provides a parameterizable interface for enabling/disabling
  scoped feature flags for specific resources (projects or sections).

  ## Usage

      <.live_component
        module={ScopedFeatureFlagsComponent}
        id="scoped_features"
        scopes={[:authoring, :both]}
        source_id={@project.id}
        source_type={:project}
        source={@project}
        current_author={@current_author}
      />

  ## Parameters

  - `scopes`: List of atoms defining which feature scopes to show (`:authoring`, `:delivery`, `:both`)
  - `source_id`: The ID of the resource (project or section)
  - `source_type`: Type of resource (`:project` or `:section`)
  - `source`: The actual resource struct (Project or Section)
  - `current_author`: The current author for audit purposes
  - `edits_enabled`: Whether editing is enabled (default: false)
  - `title`: Optional title for the component (default: "Feature Flags")
  """

  use OliWeb, :live_component

  alias Oli.ScopedFeatureFlags
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section

  @impl Phoenix.LiveComponent
  def update(%{scopes: scopes, source_type: source_type} = assigns, socket) do
    # Load all defined features
    all_features = ScopedFeatureFlags.all_defined_features()

    # Filter features based on allowed scopes
    filtered_features = filter_features_by_scopes(all_features, scopes, source_type)

    # Load current feature states for the resource
    current_flags = load_feature_states(source_type, assigns[:source])

    socket =
      socket
      |> assign(assigns)
      |> assign(
        features: filtered_features,
        current_flags: current_flags,
        edits_enabled: assigns[:edits_enabled] || false,
        title: assigns[:title] || "Feature Flags"
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="scoped-feature-flags-component">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-medium">{@title}</h3>
        <div class="flex items-center gap-2">
          <label class="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={@edits_enabled}
              phx-click="toggle_edits"
              phx-target={@myself}
              class="form-checkbox h-4 w-4"
            /> Enable Edits
          </label>
        </div>
      </div>

      <%= if Enum.empty?(@features) do %>
        <div class="text-center py-8 text-gray-500">
          <p class="mb-2">No scoped features available</p>
          <p class="text-sm">No features match the specified scopes for this resource type</p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table table-striped table-bordered w-full">
            <thead>
              <tr>
                <th class="px-4 py-2 text-left">Feature</th>
                <th class="px-4 py-2 text-left">Description</th>
                <th class="px-4 py-2 text-left">Scopes</th>
                <th class="px-4 py-2 text-left">Status</th>
                <th class="px-4 py-2 text-left">Action</th>
              </tr>
            </thead>
            <tbody>
              <%= for feature <- @features do %>
                <% current_state = get_feature_state(feature.name, @current_flags) %>
                <tr>
                  <td class="px-4 py-2 font-medium">{feature.name}</td>
                  <td class="px-4 py-2 text-sm text-gray-600">{feature.description}</td>
                  <td class="px-4 py-2">
                    <div class="flex flex-wrap gap-1">
                      <%= for scope <- feature.scopes do %>
                        <span class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">
                          {scope}
                        </span>
                      <% end %>
                    </div>
                  </td>
                  <td class="px-4 py-2">
                    <span class={[
                      "px-2 py-1 text-xs rounded-full font-medium",
                      if(current_state,
                        do: "bg-green-100 text-green-800",
                        else: "bg-gray-100 text-gray-800"
                      )
                    ]}>
                      {if current_state, do: "Enabled", else: "Disabled"}
                    </span>
                  </td>
                  <td class="px-4 py-2">
                    <%= if @edits_enabled do %>
                      <button
                        type="button"
                        class={[
                          "btn btn-sm",
                          if(current_state, do: "btn-outline-warning", else: "btn-outline-success")
                        ]}
                        phx-click="toggle_feature"
                        phx-target={@myself}
                        phx-value-feature={feature.name}
                        phx-value-enabled={to_string(!current_state)}
                      >
                        {if current_state, do: "Disable", else: "Enable"}
                      </button>
                    <% else %>
                      <span class="text-gray-500 text-sm">Enable edits to modify</span>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle_edits", _params, socket) do
    {:noreply, assign(socket, edits_enabled: !socket.assigns.edits_enabled)}
  end

  @impl Phoenix.LiveComponent
  def handle_event(
        "toggle_feature",
        %{"feature" => feature_name, "enabled" => enabled_str},
        socket
      ) do
    enabled = enabled_str == "true"
    source = socket.assigns.source
    current_author = socket.assigns.current_author

    result =
      if enabled do
        ScopedFeatureFlags.enable_feature(feature_name, source, current_author)
      else
        ScopedFeatureFlags.disable_feature(feature_name, source, current_author)
      end

    case result do
      {:ok, _} ->
        # Reload current flags
        current_flags = load_feature_states(socket.assigns.source_type, source)

        # Send success message to parent
        send(self(), {:scoped_feature_updated, feature_name, enabled, source})

        {:noreply, assign(socket, current_flags: current_flags)}

      {:error, _reason} ->
        # Send error message to parent
        send(self(), {:scoped_feature_error, feature_name, "Failed to update feature flag"})

        {:noreply, socket}
    end
  end

  # Private functions

  defp filter_features_by_scopes(features, allowed_scopes, source_type) do
    Enum.filter(features, fn feature ->
      feature_can_be_used_for_source_type(feature, source_type) and
        has_matching_scope(feature.scopes, allowed_scopes)
    end)
  end

  defp feature_can_be_used_for_source_type(feature, :project) do
    :authoring in feature.scopes or :both in feature.scopes
  end

  defp feature_can_be_used_for_source_type(feature, :section) do
    :delivery in feature.scopes or :both in feature.scopes
  end

  defp feature_can_be_used_for_source_type(_, _), do: false

  defp has_matching_scope(feature_scopes, allowed_scopes) do
    Enum.any?(feature_scopes, fn scope ->
      scope in allowed_scopes or
        (scope == :both and (:authoring in allowed_scopes or :delivery in allowed_scopes))
    end)
  end

  defp load_feature_states(:project, %Project{} = project) do
    ScopedFeatureFlags.list_project_features(project)
  end

  defp load_feature_states(:section, %Section{} = section) do
    ScopedFeatureFlags.list_section_features(section)
  end

  defp load_feature_states(_, _), do: []

  defp get_feature_state(feature_name, current_flags) do
    case Enum.find(current_flags, fn flag -> flag.feature_name == Atom.to_string(feature_name) end) do
      # Record exists = enabled
      %Oli.ScopedFeatureFlags.ScopedFeatureFlagState{} -> true
      # No record = disabled
      nil -> false
    end
  end
end
