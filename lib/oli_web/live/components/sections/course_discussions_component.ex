defmodule OliWeb.Live.Components.Sections.CourseDiscussionsComponent do
  @moduledoc """
  Self-contained LiveComponent for Course Discussions settings.

  Renders:
  - "Enable Course Discussions" toggle
  - "Allow posts to be visible without approval" checkbox (auto_accept)
  - "Show anonymous posts" checkbox (anonymous_posting)

  Manages the root container's `collab_space_config` on the section_resource level,
  plus the `contains_discussions` flag on the section itself.
  All events handled via `phx-target={@myself}` — no parent event handlers needed.
  Works for both blueprint (product) and enrollable (section) contexts.

  ## Required assigns

  - `id` — unique component ID
  - `section` — a `%Section{}` struct (blueprint or enrollable)
  - `collab_space_config` — the root container's `%CollabSpaceConfig{}` (or nil)
  - `root_section_resource` — the root container's section_resource record
  """

  use OliWeb, :live_component

  alias Oli.Delivery.Sections

  @impl true
  def update(assigns, socket) do
    collab_space_config = assigns.collab_space_config
    status = if collab_space_config, do: collab_space_config.status, else: :disabled

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:collab_space_status, status)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"course-discussions-#{@id}"}>
      <section>
        <div class="inline-flex py-2 mb-2 border-b dark:border-gray-700">
          <span>Enable Course Discussions</span>
          <.toggle_switch
            id={"#{@id}-toggle-discussions"}
            class="ml-4"
            checked={@collab_space_status == :enabled}
            on_toggle="toggle_discussions"
            name="toggle_discussions"
            phx_target={@myself}
          />
        </div>

        <div class="mt-2 space-y-2">
          <label class={[
            "flex items-center gap-2",
            if(@collab_space_status == :disabled, do: "opacity-50 cursor-not-allowed")
          ]}>
            <input
              type="checkbox"
              checked={@collab_space_config && @collab_space_config.auto_accept}
              disabled={@collab_space_status == :disabled}
              phx-click="toggle_auto_accept"
              phx-target={@myself}
              class="rounded border-gray-300 text-primary focus:ring-primary disabled:bg-gray-200 disabled:hover:bg-gray-200"
            />
            <span class="text-sm">Allow posts to be visible without approval</span>
          </label>

          <label class={[
            "flex items-center gap-2",
            if(@collab_space_status == :disabled, do: "opacity-50 cursor-not-allowed")
          ]}>
            <input
              type="checkbox"
              checked={@collab_space_config && @collab_space_config.anonymous_posting}
              disabled={@collab_space_status == :disabled}
              phx-click="toggle_anonymous_posting"
              phx-target={@myself}
              class="rounded border-gray-300 text-primary focus:ring-primary disabled:bg-gray-200 disabled:hover:bg-gray-200"
            />
            <span class="text-sm">Show anonymous posts</span>
          </label>
        </div>
      </section>
    </div>
    """
  end

  # ── Event Handlers ──

  @impl true
  def handle_event(
        "toggle_discussions",
        _params,
        %{assigns: %{root_section_resource: nil}} = socket
      ) do
    send(self(), {:flash, :error, "Cannot configure discussions: no root container found"})
    {:noreply, socket}
  end

  def handle_event("toggle_discussions", _params, socket) do
    section = socket.assigns.section
    root_sr = socket.assigns.root_section_resource
    current_config = socket.assigns.collab_space_config

    new_status = if socket.assigns.collab_space_status == :enabled, do: :disabled, else: :enabled
    contains = new_status == :enabled

    new_config_attrs =
      (current_config || %{})
      |> config_to_map()
      |> Map.put(:status, new_status)

    with {:ok, updated_sr} <-
           Sections.update_section_resource(root_sr, %{collab_space_config: new_config_attrs}),
         {:ok, updated_section} <-
           Sections.update_section(section, %{contains_discussions: contains}) do
      send(self(), {:flash, :info, "Course discussions #{new_status}"})
      send(self(), {:section_updated, updated_section})
      send(self(), {:collab_space_config_updated, updated_sr.collab_space_config, updated_sr})

      {:noreply,
       socket
       |> assign(:root_section_resource, updated_sr)
       |> assign(:collab_space_config, updated_sr.collab_space_config)
       |> assign(:collab_space_status, new_status)
       |> assign(:section, updated_section)}
    else
      {:error, _changeset} ->
        send(self(), {:flash, :error, "Failed to update course discussions"})
        {:noreply, socket}
    end
  end

  def handle_event("toggle_auto_accept", _params, socket) do
    case socket.assigns.collab_space_config do
      nil -> {:noreply, socket}
      config -> update_config_field(socket, :auto_accept, !config.auto_accept)
    end
  end

  def handle_event("toggle_anonymous_posting", _params, socket) do
    case socket.assigns.collab_space_config do
      nil -> {:noreply, socket}
      config -> update_config_field(socket, :anonymous_posting, !config.anonymous_posting)
    end
  end

  # ── Private Helpers ──

  defp update_config_field(socket, field, value) do
    root_sr = socket.assigns.root_section_resource
    current_config = socket.assigns.collab_space_config

    new_config_attrs =
      current_config
      |> config_to_map()
      |> Map.put(field, value)

    case Sections.update_section_resource(root_sr, %{collab_space_config: new_config_attrs}) do
      {:ok, updated_sr} ->
        send(self(), {:flash, :info, "Discussion settings updated"})
        send(self(), {:collab_space_config_updated, updated_sr.collab_space_config, updated_sr})

        {:noreply,
         socket
         |> assign(:root_section_resource, updated_sr)
         |> assign(:collab_space_config, updated_sr.collab_space_config)}

      {:error, _changeset} ->
        send(self(), {:flash, :error, "Failed to update discussion settings"})
        {:noreply, socket}
    end
  end

  defp config_to_map(nil), do: %{}
  defp config_to_map(%{__struct__: _} = config), do: Map.from_struct(config)
  defp config_to_map(config) when is_map(config), do: config
end
