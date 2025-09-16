defmodule OliWeb.Delivery.Remix.AddMaterialsModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Common.Hierarchy.HierarchyPicker

  def render(%{selection: selection} = assigns) do
    assigns =
      assigns
      |> assign(
        :maybe_add_disabled,
        if can_add?(selection) do
          []
        else
          [disabled: true]
        end
      )

    ~H"""
    <div
      class="modal fade show"
      style="display: block"
      id={"#{@id}"}
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Add Materials</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
            </button>
          </div>
          <div class="modal-body">
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
          </div>
          <div class="modal-footer">
            <%= if Enum.count(@selection) > 0 do %>
              <span class="mr-2">
                {Enum.count(@selection)} items selected
              </span>
            <% end %>
            <button
              type="button"
              class="btn btn-secondary"
              data-bs-dismiss="modal"
              phx-click="AddMaterialsModal.cancel"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="btn btn-primary"
              onclick={"$('##{@id}').modal('hide')"}
              phx-click="AddMaterialsModal.add"
              {@maybe_add_disabled}
            >
              Add
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp can_add?(selection) do
    !Enum.empty?(selection)
  end
end
