defmodule OliWeb.Common.RadioButton do
  use Phoenix.Component

  slot :inner_block, required: true

  def group(assigns) do
    ~H"""
      <div class="flex flex-wrap gap-2 torus-button-radio-group">
        <%= render_slot(@inner_block) %>
      </div>
    """
  end

  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :value, :string, required: true
  attr :label, :string, required: true

  def item(assigns) do
    ~H"""
      <label class="torus-custom-radio">
        <%= Phoenix.HTML.Form.radio_button @form, @field, @value, id: "#{@value}_radio_button" %>
        <span><%= @label %></span>
      </label>
    """
  end
end
