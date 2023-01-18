defmodule OliWeb.Projects.LmsUrlToCopy do
  use Surface.Component

  prop id, :string, required: true
  prop title, :string, required: true
  prop value, :string, required: true

  def render(assigns) do
    ~F"""
      <strong>{@title}:</strong>
      <div class="input-group input-group-sm mb-3">
        <input type="text" id={@id} class="form-control" value={@value} readonly>
        <div class="input-group-append">
          <button class="clipboardjs btn btn-xs btn-outline-primary" data-clipboard-target={"##{@id}"}>
            <i class="lar la-clipboard"></i> Copy
          </button>
        </div>
      </div>
    """
  end
end
