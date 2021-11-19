defmodule OliWeb.Common.Hierarchy.SelectResourceModal do
  use Surface.Component

  alias OliWeb.Common.Hierarchy.HierarchyPicker

  prop hierarchy, :struct, required: true
  prop active, :struct, required: true
  prop selection, :any, required: true
  prop filter_items_fn, :fun, default: nil

  prop on_select, :event, required: true
  prop on_cancel, :event, default: nil

  def render(
        %{
          id: id,
          hierarchy: hierarchy,
          active: active,
          selection: selection
        } = assigns
      ) do
    ~F"""
    <div class="modal fade show" style="display: block" id={id} tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Select Resource</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              {live_component HierarchyPicker,
                id: "#{id}_hierarchy_picker",
                hierarchy: hierarchy,
                active: active,
                select_mode: :single,
                selection: selection,
                filter_items_fn: @filter_items_fn}
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal" :on-click={@on_cancel}>Cancel</button>
              <button type="submit"
                class="btn btn-primary"
                disabled={selection == nil}
                :on-click={@on_select}
                phx-value-selection={selection}>
                Select
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end
end
