defmodule OliWeb.Common.Properties.ReadOnly do
  use OliWeb, :html

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :type, :string, default: "text"
  attr :show_copy_btn, :boolean, default: false
  attr :link_label, :string
  attr :class, :string, default: nil
  attr :copy_style, :atom, default: :default, values: [:default, :abutted]
  attr :input_class, :string, default: nil
  attr :button_class, :string, default: nil

  def render(assigns) do
    ~H"""
    <div class={["form-group", @class]}>
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
    <div class={["flex w-full items-stretch", if(@copy_style == :abutted, do: "gap-0", else: "gap-2")]}>
      <input
        id={@copy_id}
        class={[
          "form-control flex-1",
          if(@copy_style == :abutted, do: "rounded-r-none border-r-0", else: "rounded-md"),
          @input_class
        ]}
        type={@type}
        disabled
        value={@value}
      />
      <button
        id={"#{@copy_id}-button"}
        type="button"
        class={[
          "inline-flex items-center gap-1 border border-Border-border-default px-3 py-2 text-Text-text-low hover:text-Text-text-high focus:ring-2 focus:ring-inset focus:ring-blue-500 sm:text-sm",
          if(@copy_style == :abutted,
            do: "rounded-r-md rounded-l-none border-l-0",
            else: "rounded-md"
          ),
          @button_class
        ]}
        data-clipboard-target={"##{@copy_id}"}
        phx-hook="CopyListener"
      >
        <i class="fa-regular fa-clipboard"></i> Copy
      </button>
    </div>
    """
  end

  defp render_property(assigns) do
    ~H"""
    <input class="form-control" type={@type} disabled value={@value} />
    """
  end
end
