defmodule OliWeb.Objectives.Actions do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  def render(assigns) do
    ~H"""
      <div class="objective-actions p-2">

        <button
          class="ml-1 btn btn-sm btn-light"
          phx-click="modify"
          phx-value-slug={@slug}>
        <i class="las la-i-cursor"></i> Reword
        </button>

        <button
          id={"delete_#{@slug}"}
          {if @can_delete? do [] else [disabled: true] end}
          phx-click="show_delete_modal"
          phx-value-slug={@slug}
          data-backdrop="static"
          data-keyboard="false"
          class="ml-1 btn btn-sm btn-danger">
        <i class="fas fa-trash-alt fa-lg"></i> Remove
        </button>

      </div>
    """
  end
end
