defmodule OliWeb.Common.Properties.ReadOnly do
  use Surface.Component

  prop label, :string, required: true
  prop value, :string, required: true
  prop type, :string, default: "text"

  def render(assigns) do
    ~F"""
    <div class="form-group">
      <label>{@label}</label>
      <input class="form-control" type={@type} disabled value={@value}/>
    </div>
    """
  end
end
