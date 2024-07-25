defmodule OliWeb.Common.Hierarchy.SelectResourceModal do
  use OliWeb, :html

  alias OliWeb.Common.Hierarchy.HierarchyPicker

  attr :id, :string, required: true
  attr :hierarchy, :map, required: true
  attr :active, :map, required: true
  attr :selection, :any, required: true
  attr :filter_items_fn, :any, default: nil

  attr :on_select, :string, required: true
  attr :on_cancel, :string, default: nil

  def render(
        %{
          id: _id,
          hierarchy: _hierarchy,
          active: _active,
          selection: _selection
        } = assigns
      ) do
    ~H"""
    <div
      class="modal fade show"
      style="display: block"
      id={@id}
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Select Resource</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
            </button>
          </div>
          <div class="modal-body">
            <.live_component
              module={HierarchyPicker}
              id={"#{@id}_hierarchy_picker"}
              hierarchy={@hierarchy}
              active={@active}
              select_mode={:single}
              selection={@selection}
              filter_items_fn={@filter_items_fn}
            />
          </div>
          <div class="modal-footer">
            <button
              type="button"
              class="btn btn-secondary"
              data-bs-dismiss="modal"
              phx-click={@on_cancel}
            >
              Cancel
            </button>
            <button
              type="submit"
              class="btn btn-primary"
              disabled={@selection == nil}
              phx-click={@on_select}
              phx-value-selection={@selection}
            >
              Select
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
