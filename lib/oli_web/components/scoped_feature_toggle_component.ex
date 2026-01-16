defmodule OliWeb.Components.ScopedFeatureToggleComponent do
  @moduledoc """
  Lightweight LiveComponent that surfaces scoped feature flag toggles for a project or section.
  """

  use OliWeb, :live_component

  alias MapSet
  alias Oli.Features
  alias Oli.ScopedFeatureFlags
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:edits_enabled, fn -> Map.get(assigns, :edits_enabled, false) end)
      |> assign_new(:title, fn -> Map.get(assigns, :title, "Feature Flags") end)
      |> load_features()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="scoped-feature-toggle-component space-y-4">
      <div class="flex items-center justify-between">
        <h3 class="text-lg font-semibold text-gray-900">{@title}</h3>
        <label class="flex items-center gap-2 text-sm text-gray-700">
          <input
            type="checkbox"
            checked={@edits_enabled}
            phx-click="toggle_edits"
            phx-target={@myself}
            class="form-checkbox h-4 w-4"
          /> Enable edits
        </label>
      </div>

      <%= if Enum.empty?(@features) do %>
        <div class="rounded border border-dashed border-gray-300 bg-gray-50 px-6 py-8 text-center text-sm text-gray-600">
          <p class="font-medium">No scoped features available</p>
          <p class="mt-1 text-xs text-gray-500">
            No features match the configured scopes for this resource.
          </p>
        </div>
      <% else %>
        <div class="divide-y divide-gray-200 overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm">
          <div
            :for={feature <- @features}
            class="grid gap-4 px-6 py-4 md:grid-cols-12 md:items-center"
          >
            <div class="md:col-span-4">
              <h4 class="text-sm font-semibold text-gray-900">
                {feature_display_name(feature.name)}
              </h4>
              <p class="mt-1 text-xs text-gray-600 leading-relaxed">{feature.description}</p>
            </div>

            <div class="md:col-span-3">
              <div class="flex flex-wrap gap-2">
                <span
                  :for={scope <- feature.scopes}
                  class="inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-700"
                >
                  {scope_label(scope)}
                </span>
                <span
                  :if={feature.metadata.rollout_mode == :canary}
                  class="inline-flex items-center rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-semibold text-indigo-700"
                >
                  Canary
                </span>
              </div>
            </div>

            <div class="md:col-span-3">
              <span class={[
                "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold",
                if(feature.enabled?,
                  do: "bg-green-100 text-green-800",
                  else: "bg-gray-100 text-gray-700"
                )
              ]}>
                {if feature.enabled?, do: "Enabled", else: "Disabled"}
              </span>
            </div>

            <div class="md:col-span-2 text-right">
              <%= if @edits_enabled do %>
                <button
                  type="button"
                  class={[
                    "rounded border px-3 py-1 text-xs font-medium transition",
                    if(feature.enabled?,
                      do: "border-red-300 text-red-700 hover:bg-red-50",
                      else: "border-green-300 text-green-700 hover:bg-green-50"
                    )
                  ]}
                  phx-click="toggle_feature"
                  phx-target={@myself}
                  phx-value-feature={Atom.to_string(feature.name)}
                  phx-value-enabled={to_string(!feature.enabled?)}
                >
                  {if feature.enabled?, do: "Disable", else: "Enable"}
                </button>
              <% else %>
                <span class="text-xs text-gray-500">Enable edits to modify</span>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_edits", _params, socket) do
    {:noreply, assign(socket, :edits_enabled, !socket.assigns.edits_enabled)}
  end

  def handle_event(
        "toggle_feature",
        %{"feature" => feature_name, "enabled" => enabled_str},
        socket
      ) do
    if not socket.assigns.edits_enabled do
      {:noreply, socket}
    else
      feature_atom = safe_to_existing_atom(feature_name)

      if is_nil(feature_atom) do
        send(self(), {:scoped_feature_error, feature_name, "Unknown feature"})
        {:noreply, socket}
      else
        resource = socket.assigns.source
        actor = Map.get(socket.assigns, :current_author)
        enable? = enabled_str == "true"
        feature_allowed? = scoped_feature_allowed?(feature_atom, socket.assigns.source_type)

        if feature_allowed? do
          result =
            if enable? do
              ScopedFeatureFlags.enable_feature(feature_atom, resource, actor)
            else
              ScopedFeatureFlags.disable_feature(feature_atom, resource, actor)
            end

          case result do
            {:ok, _} ->
              socket =
                socket
                |> load_features()

              send(
                self(),
                {:scoped_feature_updated, Atom.to_string(feature_atom), enable?, resource}
              )

              {:noreply, socket}

            {:error, reason} ->
              send(self(), {:scoped_feature_error, feature_name, error_message(reason)})
              {:noreply, socket}
          end
        else
          send(
            self(),
            {:scoped_feature_error, feature_name, "ClickHouse analytics is not enabled"}
          )

          {:noreply, socket}
        end
      end
    end
  end

  defp load_features(
         %{assigns: %{source: source, source_type: source_type, scopes: scopes}} = socket
       ) do
    enabled_names = enabled_feature_names(source_type, source)

    features =
      ScopedFeatureFlags.all_defined_features()
      |> filter_features_by_scopes(scopes, socket.assigns.source_type)
      |> filter_olap_features(socket.assigns.source_type)
      |> Enum.map(&decorate_feature(&1, enabled_names))

    assign(socket, :features, features)
  end

  defp decorate_feature(feature, enabled_names) do
    feature_string = Atom.to_string(feature.name)
    Map.put(feature, :enabled?, MapSet.member?(enabled_names, feature_string))
  end

  defp enabled_feature_names(:project, %Project{} = project) do
    project
    |> ScopedFeatureFlags.list_project_features()
    |> Enum.map(& &1.feature_name)
    |> MapSet.new()
  end

  defp enabled_feature_names(:section, %Section{} = section) do
    section
    |> ScopedFeatureFlags.list_section_features()
    |> Enum.map(& &1.feature_name)
    |> MapSet.new()
  end

  defp enabled_feature_names(_type, _resource), do: MapSet.new()

  defp filter_features_by_scopes(features, allowed_scopes, source_type)
       when is_list(allowed_scopes) do
    Enum.filter(features, fn feature ->
      scope_allowed?(feature, allowed_scopes) and
        feature_matches_source_type?(feature, source_type)
    end)
  end

  defp filter_features_by_scopes(features, _allowed_scopes, source_type) do
    Enum.filter(features, &feature_matches_source_type?(&1, source_type))
  end

  defp scope_allowed?(feature, allowed_scopes) do
    allowed_set = MapSet.new(allowed_scopes)

    cond do
      MapSet.member?(allowed_set, :both) -> true
      Enum.any?(feature.scopes, &MapSet.member?(allowed_set, &1)) -> true
      true -> false
    end
  end

  defp feature_matches_source_type?(feature, :project) do
    :authoring in feature.scopes or :both in feature.scopes
  end

  defp feature_matches_source_type?(feature, :section) do
    :delivery in feature.scopes or :both in feature.scopes
  end

  defp feature_matches_source_type?(_feature, _source_type), do: true

  defp filter_olap_features(features, :section) do
    if Features.enabled?("clickhouse-olap") do
      features
    else
      Enum.reject(features, &(&1.name == :instructor_dashboard_analytics))
    end
  end

  defp filter_olap_features(features, _source_type), do: features

  defp scoped_feature_allowed?(:instructor_dashboard_analytics, :section) do
    Features.enabled?("clickhouse-olap")
  end

  defp scoped_feature_allowed?(_feature, _source_type), do: true

  defp feature_display_name(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp scope_label(:authoring), do: "Authoring"
  defp scope_label(:delivery), do: "Delivery"
  defp scope_label(:both), do: "Both"
  defp scope_label(scope), do: scope |> Atom.to_string() |> String.capitalize()

  defp safe_to_existing_atom(value) when is_atom(value), do: value

  defp safe_to_existing_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> nil
  end

  defp safe_to_existing_atom(_), do: nil

  defp error_message(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, messages} -> "#{field}: #{Enum.join(List.wrap(messages), ", ")}" end)
    |> Enum.join("; ")
  end

  defp error_message(reason), do: inspect(reason)
end
