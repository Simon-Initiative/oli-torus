defmodule OliWeb.Delivery.Remix.AddMaterialsModal do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias OliWeb.Common.Hierarchy.HierarchyPicker
  alias OliWeb.Components.Modal
  alias OliWeb.Components.DesignTokens.Primitives.Button

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :hierarchy, :any
  attr :active, :any
  attr :selection, :list, default: []
  attr :preselected, :list, default: []
  attr :publications, :list, default: []
  attr :selected_publication, :any
  attr :active_tab, :atom, default: :curriculum
  attr :pages_table_model, :any
  attr :pages_table_model_params, :any
  attr :pages_table_model_total_count, :integer, default: 0
  attr :publications_table_model, :any
  attr :publications_table_model_params, :any
  attr :publications_table_model_total_count, :integer, default: 0

  def render(assigns) do
    assigns = assign(assigns, :add_disabled, Enum.empty?(assigns.selection))

    ~H"""
    <Modal.modal
      id={@id}
      show={@show}
      show_close={false}
      class="md:w-8/12"
      container_class="rounded-[16px] border border-Border-border-default shadow-[0px_2px_10px_0px_rgba(0,50,99,0.1)] p-16"
      header_class="flex items-start justify-between"
      title_class="text-[24px] font-bold leading-[32px] text-Text-text-high"
      subtitle_class="mt-3 text-[16px] font-medium text-Text-text-medium"
      body_class="space-y-[10px] mt-4"
      on_cancel={JS.push("close_add_materials_modal")}
    >
      <:title>Add Materials</:title>
      <:subtitle>Materials can only be added to the curriculum once.</:subtitle>
      <:header_actions>
        <button
          type="button"
          class="absolute top-8 right-8 size-5 flex items-center justify-center text-Icon-icon-default hover:text-Icon-icon-hover"
          phx-click={JS.push("close_add_materials_modal")}
          aria-label="Close"
        >
          <OliWeb.Icons.close_sm class="w-5 h-5 stroke-current" />
        </button>
      </:header_actions>

      <HierarchyPicker.render
        id="hierarchy_picker"
        select_mode={:multiple}
        hierarchy={@hierarchy}
        active={@active}
        selection={@selection}
        preselected={@preselected}
        publications={@publications}
        selected_publication={@selected_publication}
        active_tab={@active_tab}
        pages_table_model_total_count={@pages_table_model_total_count}
        pages_table_model_params={@pages_table_model_params}
        pages_table_model={@pages_table_model}
        publications_table_model={@publications_table_model}
        publications_table_model_total_count={@publications_table_model_total_count}
        publications_table_model_params={@publications_table_model_params}
      />

      <:custom_footer>
        <div class="flex items-center justify-end gap-4 mt-4">
          <span :if={length(@selection) > 0} class="text-sm text-zinc-500 mr-auto">
            {length(@selection)} items selected
          </span>
          <Button.button
            variant={:secondary}
            size={:sm}
            phx-click={JS.push("close_add_materials_modal")}
          >
            Cancel
          </Button.button>
          <Button.button
            variant={:primary}
            size={:sm}
            phx-click="AddMaterialsModal.add"
            disabled={@add_disabled}
          >
            Add
          </Button.button>
        </div>
      </:custom_footer>
    </Modal.modal>
    """
  end
end
