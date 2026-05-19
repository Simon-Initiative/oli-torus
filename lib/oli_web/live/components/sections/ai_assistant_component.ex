defmodule OliWeb.Live.Components.Sections.AiAssistantComponent do
  @moduledoc """
  Self-contained LiveComponent for AI Assistant settings.

  Renders:
  - "Enable AI Assistant" toggle (persists `assistant_enabled`)
  - "Enable AI Activation Points" toggle (persists `triggers_enabled`)
  - Prompt Templates Monaco editor (persists `page_prompt_template`)
  - Save button for prompt template

  All events handled via `phx-target={@myself}` — no parent event handlers needed.
  Works for both blueprint (product) and enrollable (section) contexts.

  ## Required assigns

  - `id` — unique component ID
  - `section` — a `%Section{}` struct (blueprint or enrollable)
  """

  use OliWeb, :live_component

  alias Oli.Delivery.Sections
  alias OliWeb.Common.Monaco

  @impl true
  def update(assigns, socket) do
    section = assigns.section

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:page_prompt_template, fn -> section.page_prompt_template end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"ai-assistant-#{@id}"}>
      <%!-- Toggles --%>
      <div>
        <div class="flex py-2 mb-2">
          <div>Enable AI Assistant</div>
          <.toggle_switch
            id={"#{@id}-toggle-assistant"}
            class="ml-4"
            checked={@section.assistant_enabled}
            on_toggle="toggle_assistant"
            name="toggle_assistant"
            phx_target={@myself}
          />
        </div>
        <div class="flex py-2 mb-2">
          <div>Enable AI Activation Points</div>
          <.toggle_switch
            id={"#{@id}-toggle-triggers"}
            class="ml-4"
            checked={@section.triggers_enabled}
            on_toggle="toggle_triggers"
            name="toggle_triggers"
            phx_target={@myself}
          />
        </div>
      </div>

      <%!-- Prompt template editor (visible when assistant is enabled) --%>
      <div :if={@section.assistant_enabled}>
        <section class="flex flex-col space-y-4 mt-8 pt-6 border-t border-gray-200">
          <h5>Prompt Templates</h5>

          <Monaco.editor
            id={"#{@id}-monaco-editor"}
            height="200px"
            language="text"
            on_change="monaco_editor_on_change"
            set_options="monaco_editor_set_options"
            set_value="monaco_editor_set_value"
            get_value="monaco_editor_get_value"
            validate_schema_uri=""
            target={@myself}
            default_value={@section.page_prompt_template || ""}
            default_options={
              %{
                "readOnly" => false,
                "selectOnLineNumbers" => true,
                "minimap" => %{"enabled" => false},
                "scrollBeyondLastLine" => false,
                "tabSize" => 2
              }
            }
            use_code_lenses={[]}
          />

          <div>
            <button
              type="button"
              class="btn btn-primary action-button mt-4"
              phx-click="save_prompt"
              phx-target={@myself}
            >
              Save
            </button>
          </div>
        </section>
      </div>
    </div>
    """
  end

  # ── Event Handlers ──

  @impl true
  def handle_event("toggle_assistant", _params, socket) do
    section = socket.assigns.section
    assistant_enabled = section.assistant_enabled

    # When disabling assistant, also disable triggers
    triggers_enabled =
      if assistant_enabled do
        false
      else
        section.triggers_enabled
      end

    case Sections.update_section(section, %{
           assistant_enabled: !assistant_enabled,
           triggers_enabled: triggers_enabled
         }) do
      {:ok, updated_section} ->
        send(self(), {:flash, :info, "AI assistant settings updated successfully"})
        send(self(), {:section_updated, updated_section})
        {:noreply, assign(socket, :section, updated_section)}

      {:error, _changeset} ->
        send(self(), {:flash, :error, "Failed to update AI assistant settings"})
        {:noreply, socket}
    end
  end

  def handle_event("toggle_triggers", _params, socket) do
    section = socket.assigns.section

    case Sections.update_section(section, %{triggers_enabled: !section.triggers_enabled}) do
      {:ok, updated_section} ->
        send(self(), {:flash, :info, "AI assistant activation settings updated successfully"})
        send(self(), {:section_updated, updated_section})
        {:noreply, assign(socket, :section, updated_section)}

      {:error, _changeset} ->
        send(self(), {:flash, :error, "Failed to update activation settings"})
        {:noreply, socket}
    end
  end

  def handle_event("monaco_editor_on_change", value, socket) do
    {:noreply, assign(socket, :page_prompt_template, value)}
  end

  def handle_event("save_prompt", _params, socket) do
    section = socket.assigns.section

    case Sections.update_section(section, %{
           page_prompt_template: socket.assigns.page_prompt_template
         }) do
      {:ok, updated_section} ->
        send(self(), {:flash, :info, "Prompt successfully saved"})
        send(self(), {:section_updated, updated_section})
        {:noreply, assign(socket, :section, updated_section)}

      {:error, _changeset} ->
        send(self(), {:flash, :error, "Failed to save prompt template"})
        {:noreply, socket}
    end
  end
end
