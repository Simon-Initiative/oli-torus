defmodule OliWeb.Common.CustomCheckbox do
  use Phoenix.Component

  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :value, :string, required: true
  attr :label, :string, required: true
  attr :checked, :boolean, default: false

  def item(assigns) do
    ~H"""
      <label class="torus-custom-checkbox">
        <input type="checkbox" name={Phoenix.HTML.Form.input_name(@form, @field)} value={@value} checked={@checked} id={"#{@value}_radio_button"} />
        <span><%= @label %></span>
      </label>
    """
  end
end
