defmodule OliWeb.Live.Components.Sections.InstructorAiRecommendationsComponent do
  @moduledoc """
  LiveComponent for section-level instructor AI recommendation settings.

  Renders:
  - Enable/disable toggle for instructor AI recommendations
  - Prompt template editor used by summary recommendation generation
  - Save action that persists the prompt template
  """

  use OliWeb, :live_component

  alias Oli.Delivery.Sections
  alias Oli.InstructorDashboard.Recommendations.Prompt
  alias OliWeb.Common.Monaco

  @impl true
  def update(assigns, socket) do
    section = assigns.section

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:instructor_recommendation_prompt_template, fn ->
       section.instructor_recommendation_prompt_template || Prompt.default_template()
     end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"instructor-ai-recommendations-#{@id}"} class="text-[#373A44]">
      <div class="flex py-2 mb-2">
        <div class="font-open-sans text-[16px] leading-[24px] text-[#373A44] dark:text-white">
          Enable AI Recommendations
        </div>
        <.toggle_switch
          id={"#{@id}-toggle-recommendations"}
          class="ml-4"
          checked={@section.instructor_recommendations_enabled}
          on_toggle="toggle_instructor_recommendations"
          name="toggle_instructor_recommendations"
          phx_target={@myself}
        />
      </div>

      <section class="mt-8 flex flex-col space-y-4 border-t border-Border-border-default pt-6">
        <h5 class="text-[#373A44] dark:text-white">Prompt Templates</h5>

        <Monaco.editor
          id={"#{@id}-monaco-editor"}
          height="200px"
          language="text"
          on_change="monaco_editor_on_change"
          set_options="monaco_editor_set_options"
          set_value={set_value_event(@id)}
          get_value="monaco_editor_get_value"
          validate_schema_uri=""
          target={@myself}
          default_value={@instructor_recommendation_prompt_template}
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
            phx-click="save_instructor_recommendation_prompt"
            phx-disable-with="Saving..."
            phx-target={@myself}
          >
            Save
          </button>
        </div>
      </section>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_instructor_recommendations", _params, socket) do
    section = socket.assigns.section

    case Sections.update_section(section, %{
           instructor_recommendations_enabled: !section.instructor_recommendations_enabled
         }) do
      {:ok, updated_section} ->
        send(
          self(),
          {:flash, :info, "Instructor AI recommendation settings updated successfully"}
        )

        send(self(), {:section_updated, updated_section})
        {:noreply, assign(socket, :section, updated_section)}

      {:error, _changeset} ->
        send(self(), {:flash, :error, "Failed to update instructor AI recommendation settings"})
        {:noreply, socket}
    end
  end

  def handle_event("monaco_editor_on_change", value, socket) do
    {:noreply, assign(socket, :instructor_recommendation_prompt_template, value)}
  end

  def handle_event("save_instructor_recommendation_prompt", _params, socket) do
    section = socket.assigns.section

    blank_prompt? =
      blank_prompt_template?(socket.assigns.instructor_recommendation_prompt_template)

    prompt_template =
      socket.assigns.instructor_recommendation_prompt_template
      |> normalize_prompt_template()

    case Sections.update_section(section, %{
           instructor_recommendation_prompt_template: prompt_template
         }) do
      {:ok, updated_section} ->
        flash_message =
          if blank_prompt? do
            "Prompt template was empty and has been reset to the default prompt"
          else
            "Instructor AI recommendation prompt saved"
          end

        send(self(), {:flash, :info, flash_message})
        send(self(), {:section_updated, updated_section})

        {:noreply,
         socket
         |> assign(:section, updated_section)
         |> assign(:instructor_recommendation_prompt_template, prompt_template)
         |> push_event(set_value_event(socket.assigns.id), %{value: prompt_template})}

      {:error, _changeset} ->
        send(self(), {:flash, :error, "Failed to save instructor AI recommendation prompt"})
        {:noreply, socket}
    end
  end

  defp normalize_prompt_template(prompt_template) when is_binary(prompt_template) do
    case String.trim(prompt_template) do
      "" -> Prompt.default_template()
      _ -> prompt_template
    end
  end

  defp normalize_prompt_template(_), do: Prompt.default_template()

  defp blank_prompt_template?(prompt_template) when is_binary(prompt_template) do
    String.trim(prompt_template) == ""
  end

  defp blank_prompt_template?(_), do: true

  defp set_value_event(id), do: "instructor_ai_recommendations_set_value:#{id}"
end
