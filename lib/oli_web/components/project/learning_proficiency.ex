defmodule OliWeb.Components.Project.LearningProficiency do
  @moduledoc "Project proficiency settings and the typed confirmation for a framework upgrade."
  use OliWeb, :html

  alias OliWeb.Components.{Modal, Overview}
  alias OliWeb.Components.DesignTokens.Primitives.Button

  attr :project, :map, required: true
  attr :confirming, :boolean, required: true
  attr :confirmation, :string, required: true

  @doc "Renders the current framework and its irreversible upgrade confirmation."
  def settings(assigns) do
    ~H"""
    <div id="learning-proficiency-settings">
      <Overview.section
        title="Learning Proficiency"
        description="Learn more about how learning proficiency is calculated in course sections made from this project and its templates."
      >
        <div class="flex flex-col items-start gap-3 text-sm text-Text-text-high">
          <div>
            <div>Learning proficiency framework</div>
            <div>{version_label(@project.learning_model_version)}</div>
          </div>
          <.link
            href={~p"/workspaces/course_author/#{@project.slug}/learning_proficiency"}
            target="_blank"
            rel="noopener noreferrer"
            class="font-bold text-Text-text-button hover:underline"
          >
            Learn more
          </.link>
          <Button.button
            id="upgrade-learning-framework"
            variant={:secondary}
            size={:sm}
            phx-click="show_framework_upgrade"
            disabled={@project.learning_model_version != :naive}
          >
            Update to latest framework
          </Button.button>
        </div>
      </Overview.section>

      <Modal.modal
        :if={@confirming}
        id="framework-upgrade-modal"
        show={true}
        on_cancel={JS.push("cancel_framework_upgrade")}
        wrapper_class="w-full max-w-lg p-4"
        container_class="rounded-xl text-Text-text-high"
        header_class="flex items-start justify-between gap-3 px-8 pt-8 pb-3"
        title_class="text-xl font-bold leading-7 text-Text-text-high"
        body_class="px-8 pb-10 text-sm leading-5"
      >
        <:title>Confirm Update to Learning Proficiency Framework</:title>
        <.link
          href={~p"/workspaces/course_author/#{@project.slug}/learning_proficiency"}
          target="_blank"
          rel="noopener noreferrer"
          class="font-bold text-Text-text-button hover:underline"
        >
          Learn more about the current learning proficiency framework.
        </.link>
        <p id="framework-upgrade-modal-description" class="mt-4 mb-6">
          Updating to the latest learning proficiency framework will update this project and all its existing templates.
          Newly created course sections from this project or its templates will use the new framework.
          Existing course sections will keep their current framework.
          Existing learner proficiency data will not be recalculated.
          This change is permanent and cannot be undone. Are you sure you want to update?
        </p>
        <.form
          for={%{}}
          id="framework-upgrade-form"
          phx-change="validate_framework_upgrade"
          phx-submit="upgrade_framework"
        >
          <label for="framework-upgrade-confirmation" class="block mb-2">
            Please type <strong>Update Framework</strong> to confirm.
          </label>
          <input
            id="framework-upgrade-confirmation"
            name="confirmation"
            type="text"
            value={@confirmation}
            placeholder="Type here..."
            autocomplete="off"
            class="w-full rounded-lg border border-Border-border-default bg-Surface-surface-primary px-3 py-2 text-sm text-Text-text-high placeholder:text-Text-text-low focus:ring-2 focus:ring-Fill-Buttons-fill-primary"
          />
          <div class="mt-5 flex flex-wrap justify-end gap-2">
            <Button.button variant={:secondary} phx-click="cancel_framework_upgrade">
              Cancel
            </Button.button>
            <Button.button
              id="confirm-framework-upgrade"
              type="submit"
              disabled={@confirmation != "Update Framework"}
            >
              Update Framework
            </Button.button>
          </div>
        </.form>
      </Modal.modal>
    </div>
    """
  end

  @doc "Returns the display version used in project proficiency settings."
  def version_label(:naive), do: "v0.1.0"
  def version_label(:lkt_aoa), do: "v0.2.0"
end
