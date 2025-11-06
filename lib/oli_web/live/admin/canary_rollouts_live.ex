defmodule OliWeb.Admin.CanaryRolloutsLive do
  @moduledoc """
  System-admin dashboard for managing canary rollouts across all features.
  """

  use OliWeb, :live_view

  alias Oli.Repo
  alias Oli.ScopedFeatureFlags
  alias Oli.ScopedFeatureFlags.Rollouts
  alias Oli.ScopedFeatureFlags.ScopedFeatureRollout
  alias Oli.Inventories.Publisher

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  @stage_sequence [:off, :internal_only, :five_percent, :fifty_percent, :full]
  @stage_labels %{
    off: "Off",
    internal_only: "Internal",
    five_percent: "5%",
    fifty_percent: "50%",
    full: "Full"
  }
  @pubsub_topic "feature_rollouts"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Oli.PubSub, @pubsub_topic)
    end

    {:ok,
     socket
     |> assign(
       editing?: false,
       feature_entries: fetch_feature_entries(),
       stage_sequence: @stage_sequence,
       stage_labels: @stage_labels,
       breadcrumbs: breadcrumbs()
     )}
  end

  @impl true
  def handle_event("enable_editing", _params, socket) do
    {:noreply, assign(socket, editing?: true)}
  end

  def handle_event("disable_editing", _params, socket) do
    {:noreply,
     socket
     |> assign(editing?: false)
     |> reload_features()}
  end

  def handle_event(
        "set_stage",
        %{
          "feature" => feature,
          "scope_type" => scope_type,
          "scope_id" => _scope_id,
          "stage" => stage
        },
        %{assigns: %{editing?: true}} = socket
      ) do
    with {:ok, scope_type_atom} <- parse_scope_type(scope_type),
         :global <- scope_type_atom,
         {:ok, stage_atom} <- parse_stage(stage),
         {:ok, _} <-
           Rollouts.upsert_rollout(
             feature,
             :global,
             nil,
             stage_atom,
             socket.assigns.current_author,
             []
           ) do
      {:noreply,
       socket
       |> put_flash(:info, "Updated #{feature} global stage to #{stage_label(stage_atom)}")
       |> reload_features()}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, humanize_error(reason))}

      _other ->
        {:noreply, put_flash(socket, :error, "Invalid scope for stage change")}
    end
  end

  def handle_event("set_stage", _params, socket), do: {:noreply, socket}

  def handle_event(
        "add_exemption",
        %{
          "feature" => feature,
          "publisher_id" => publisher_id,
          "effect" => effect,
          "note" => note
        },
        %{assigns: %{editing?: true}} = socket
      ) do
    with {:ok, publisher_id_int} <- parse_integer(publisher_id),
         {:ok, effect_atom} <- parse_effect(effect),
         {:ok, _} <-
           Rollouts.upsert_exemption(
             feature,
             publisher_id_int,
             effect_atom,
             socket.assigns.current_author,
             note: empty_to_nil(note)
           ) do
      {:noreply,
       socket
       |> put_flash(:info, "Updated exemption for #{feature}")
       |> reload_features()}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, humanize_error(reason))}
    end
  end

  def handle_event("add_exemption", _params, socket), do: {:noreply, socket}

  def handle_event(
        "remove_exemption",
        %{"feature" => feature, "publisher_id" => publisher_id},
        %{assigns: %{editing?: true}} = socket
      ) do
    with {:ok, publisher_id_int} <- parse_integer(publisher_id),
         :ok <-
           Rollouts.delete_exemption(
             feature,
             publisher_id_int,
             socket.assigns.current_author,
             []
           ) do
      {:noreply,
       socket
       |> put_flash(:info, "Removed exemption for #{feature}")
       |> reload_features()}
    else
      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "No exemption found")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, humanize_error(reason))}
    end
  end

  def handle_event("remove_exemption", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:stage_invalidated, _feature, _scope_type, _scope_id}, socket) do
    {:noreply, reload_features(socket)}
  end

  def handle_info({:exemption_invalidated, _feature, _publisher_id}, socket) do
    {:noreply, reload_features(socket)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900">Incremental Feature Rollout</h1>
          <p class="mt-1 text-sm text-gray-600">
            Review the rollout state of all incremental features. Click “Make Changes” to adjust stages or exemptions.
          </p>
        </div>
        <%= if @editing? do %>
          <.button type="button" variant={:primary} phx-click="disable_editing">
            Finish Changes
          </.button>
        <% else %>
          <.button type="button" variant={:primary} phx-click="enable_editing">
            Make Changes
          </.button>
        <% end %>
      </div>

      <%= if Enum.empty?(@feature_entries) do %>
        <div class="rounded border border-dashed border-gray-300 bg-gray-50 px-6 py-10 text-center text-sm text-gray-600">
          No incremental-enabled features are defined.
        </div>
      <% else %>
        <div class="space-y-2">
          <%= for feature <- @feature_entries do %>
            <div class="rounded border border-gray-200 bg-white px-4 py-3 shadow-sm">
              <div class="flex flex-wrap items-center gap-3">
                <div class="flex items-center gap-2 text-sm font-semibold text-gray-900">
                  <span title={feature.description}>{feature_display_name(feature.name)}</span>
                  <span class="inline-flex items-center rounded-full bg-indigo-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-indigo-700">
                    Canary
                  </span>
                  <span class="text-[11px] font-medium text-gray-500">
                    Scopes: {Enum.map_join(feature.scopes, ", ", &scope_label/1)}
                  </span>
                </div>

                <div class="flex flex-wrap items-center gap-2 text-xs text-gray-600">
                  <span class={[
                    "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold",
                    stage_badge_class(feature.global.stage)
                  ]}>
                    {stage_label(feature.global.stage)}
                  </span>
                  <span>Cohort {feature.global.rollout_percentage}%</span>
                  <span>Updated {format_timestamp(feature.global.updated_at)}</span>
                </div>

                <div class="ml-auto flex flex-wrap gap-1">
                  <%= if @editing? do %>
                    <button
                      :for={stage <- @stage_sequence}
                      type="button"
                      class={stage_button_classes(stage, feature.global.stage, @editing?)}
                      phx-click="set_stage"
                      phx-value-feature={feature.name}
                      phx-value-scope_type="global"
                      phx-value-scope_id=""
                      phx-value-stage={Atom.to_string(stage)}
                    >
                      {@stage_labels[stage]}
                    </button>
                  <% else %>
                    <span class="text-[11px] text-gray-400">Read-only</span>
                  <% end %>
                </div>
              </div>

              <div class="mt-2 space-y-2 text-xs text-gray-600">
                <div class="flex flex-wrap items-center gap-2">
                  <span class="font-medium text-gray-700">Publisher exemptions:</span>
                  <%= if Enum.empty?(feature.exemptions) do %>
                    <span class="text-gray-500">None</span>
                  <% else %>
                    <%= for exemption <- feature.exemptions do %>
                      <span class="inline-flex items-center gap-1 rounded-full bg-gray-100 px-2 py-0.5 text-gray-700">
                        <span class="font-semibold text-gray-800">{exemption.publisher_name}</span>
                        <span>{effect_label(exemption.effect)}</span>
                        <%= if exemption.note do %>
                          <span class="text-gray-500 italic">({exemption.note})</span>
                        <% end %>
                        <%= if @editing? do %>
                          <button
                            type="button"
                            class="ml-1 text-red-600 hover:text-red-800"
                            phx-click="remove_exemption"
                            phx-value-feature={feature.name}
                            phx-value-publisher_id={Integer.to_string(exemption.publisher_id)}
                          >
                            ×
                          </button>
                        <% end %>
                      </span>
                    <% end %>
                  <% end %>
                </div>

                <%= if @editing? do %>
                  <form phx-submit="add_exemption" class="flex flex-wrap items-center gap-2 text-xs">
                    <input type="hidden" name="feature" value={feature.name} />
                    <select name="publisher_id" class="form-select h-8 text-xs" required>
                      <option value="">Select publisher</option>
                      <option :for={publisher <- feature.publishers} value={publisher.id}>
                        {publisher.name}
                      </option>
                    </select>
                    <select name="effect" class="form-select h-8 text-xs" required>
                      <option value="force_enable">Force enable</option>
                      <option value="deny">Deny</option>
                    </select>
                    <input
                      type="text"
                      name="note"
                      placeholder="Optional note"
                      class="form-input h-8 w-40 text-xs"
                    />
                    <.button type="submit" size={:xs} variant={:secondary}>
                      Save
                    </.button>
                  </form>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp reload_features(socket) do
    assign(socket, :feature_entries, fetch_feature_entries())
  end

  defp fetch_feature_entries do
    features =
      ScopedFeatureFlags.all_defined_features()
      |> Enum.filter(fn feature ->
        Map.get(feature.metadata, :rollout_mode, :scoped_only) == :canary
      end)

    publishers = Repo.all(Publisher)

    Enum.map(features, &build_feature_entry(&1, publishers))
  end

  defp build_feature_entry(feature, publishers) do
    rollouts = Rollouts.list_rollouts(feature.name)
    exemptions = Rollouts.list_exemptions(feature.name)

    global_rollout =
      rollouts
      |> Enum.find(fn r -> r.scope_type == :global end)
      |> default_global_rollout()

    exemption_entries =
      exemptions
      |> Enum.map(fn exemption ->
        %{
          publisher_id: exemption.publisher_id,
          publisher_name: publisher_name(exemption.publisher_id, exemption.publisher),
          effect: exemption.effect,
          note: exemption.note,
          updated_at: exemption.updated_at,
          inserted_at: exemption.inserted_at
        }
      end)

    %{
      name: feature.name |> Atom.to_string(),
      description: feature.description,
      scopes: feature.scopes,
      metadata: feature.metadata,
      global: global_rollout,
      exemptions: exemption_entries,
      publishers: publishers
    }
  end

  defp default_global_rollout(%ScopedFeatureRollout{} = rollout), do: rollout

  defp default_global_rollout(_nil) do
    %ScopedFeatureRollout{
      feature_name: "",
      scope_type: :global,
      scope_id: nil,
      stage: :off,
      rollout_percentage: 0,
      updated_at: nil,
      inserted_at: nil
    }
  end

  defp parse_stage(stage) when is_atom(stage) and stage in @stage_sequence, do: {:ok, stage}

  defp parse_stage(stage) when is_binary(stage) do
    try do
      atom = String.to_existing_atom(stage)
      if atom in @stage_sequence, do: {:ok, atom}, else: {:error, :invalid_stage}
    rescue
      ArgumentError -> {:error, :invalid_stage}
    end
  end

  defp parse_stage(_), do: {:error, :invalid_stage}

  defp parse_scope_type("global"), do: {:ok, :global}
  defp parse_scope_type(_), do: {:error, :invalid_scope_type}

  defp parse_effect("force_enable"), do: {:ok, :force_enable}
  defp parse_effect("deny"), do: {:ok, :deny}

  defp parse_effect(effect) when is_atom(effect) and effect in [:force_enable, :deny],
    do: {:ok, effect}

  defp parse_effect(_), do: {:error, :invalid_effect}

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, :invalid_integer}
    end
  end

  defp parse_integer(value) when is_integer(value), do: {:ok, value}
  defp parse_integer(_), do: {:error, :invalid_integer}

  defp humanize_error(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, messages} -> "#{field}: #{Enum.join(List.wrap(messages), ", ")}" end)
    |> Enum.join("; ")
  end

  defp humanize_error(error) when is_atom(error), do: Atom.to_string(error)
  defp humanize_error(error), do: inspect(error)

  defp stage_label(stage), do: Map.get(@stage_labels, stage, Atom.to_string(stage))

  defp effect_label(:force_enable), do: "Force enable"
  defp effect_label(:deny), do: "Deny"
  defp effect_label(effect), do: Atom.to_string(effect)

  defp format_timestamp(nil), do: "never"
  defp format_timestamp(datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp stage_badge_class(:off), do: "bg-gray-100 text-gray-700"
  defp stage_badge_class(:internal_only), do: "bg-indigo-100 text-indigo-700"
  defp stage_badge_class(:five_percent), do: "bg-blue-100 text-blue-700"
  defp stage_badge_class(:fifty_percent), do: "bg-amber-100 text-amber-700"
  defp stage_badge_class(:full), do: "bg-green-100 text-green-800"
  defp stage_badge_class(_), do: "bg-gray-100 text-gray-700"

  defp stage_button_classes(stage, current_stage, true) do
    base = ["rounded", "border", "px-2", "py-1", "text-xs", "font-medium", "transition"]

    base =
      if stage == current_stage do
        base ++ ["bg-indigo-600", "text-white", "border-indigo-600"]
      else
        base ++ ["bg-white", "text-gray-700", "border-gray-300", "hover:bg-gray-50"]
      end

    base
  end

  defp stage_button_classes(_stage, _current_stage, false),
    do: [
      "rounded",
      "border",
      "px-2",
      "py-1",
      "text-xs",
      "font-medium",
      "opacity-40",
      "cursor-not-allowed"
    ]

  defp scope_label(scope) when is_atom(scope) do
    scope
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp scope_label(scope), do: scope

  defp feature_display_name(name) when is_binary(name) do
    name
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp feature_display_name(name) when is_atom(name),
    do: feature_display_name(Atom.to_string(name))

  defp breadcrumbs do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        %OliWeb.Common.Breadcrumb{
          full_title: "Incremental Feature Rollout",
          short_title: "Incremental Feature Rollout",
          link: ~p"/admin/canary_rollouts"
        }
      ]
  end

  defp publisher_name(_id, %Publisher{name: name}) when is_binary(name), do: name
  defp publisher_name(id, _), do: "Publisher ##{id}"
end
