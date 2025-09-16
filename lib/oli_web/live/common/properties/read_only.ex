defmodule OliWeb.Common.Properties.ReadOnly do
  use OliWeb, :html

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :type, :string, default: "text"
  attr :show_copy_btn, :boolean, default: false
  attr :link_label, :string

  def render(assigns) do
    ~H"""
    <div class="form-group">
      <label>{@label}</label>
      {render_property(assigns)}
    </div>
    """
  end

  defp render_property(%{type: "link"} = assigns) do
    ~H"""
    <.link href={@value} class="form-control">{@link_label}</.link>
    """
  end

  defp render_property(%{show_copy_btn: true} = assigns) do
    assigns = assign(assigns, :copy_id, "copy-#{UUID.uuid4(:hex)}")

    ~H"""
    <div class="relative">
      <input id={@copy_id} class="form-control" type={@type} disabled value={@value} />
      <div class="absolute inset-y-0 right-0 flex items-center">
        <button
          id={"#{@copy_id}-button"}
          class="h-full rounded-md border-0 bg-transparent py-0 px-2 text-gray-500 focus:ring-2 focus:ring-inset focus:ring-blue-500 sm:text-sm"
          data-clipboard-target={"##{@copy_id}"}
          phx-hook="CopyListener"
        >
          <i class="fa-regular fa-clipboard"></i> Copy
        </button>
      </div>
    </div>
    """
  end

  defp render_property(assigns) do
    ~H"""
    <input class="form-control" type={@type} disabled value={@value} />
    """
  end
end
