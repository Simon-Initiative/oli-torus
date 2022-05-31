defmodule OliWeb.Common.Properties.ReadOnly do
  use Surface.Component

  alias Surface.Components.Link

  prop label, :string, required: true
  prop value, :string, required: true
  prop type, :string, default: "text"
  prop link_label, :string

  def render(assigns) do
    ~F"""
    <div class="form-group">
      <label>{@label}</label>
      {render_property(assigns)}
    </div>
    """
  end

  defp render_property(%{type: "link"} = assigns) do
    ~F"""
    <Link label={@link_label} to={@value} class="form-control"/>
    """
  end

  defp render_property(assigns) do
    ~F"""
    <input class="form-control" type={@type} disabled value={@value}/>
    """
  end
end
