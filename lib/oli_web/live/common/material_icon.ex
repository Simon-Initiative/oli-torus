defmodule OliWeb.Common.MaterialIcon do
  use Phoenix.LiveComponent

  def render(assigns) do

    width = assigns.width
    icon = assigns.icon
    category = if assigns.category === nil do
      ""
    else
      "-" <> assigns.category
    end

    ~L"""
    <i style="width: <%= width %>px;" class='material-icons<%= category %> icon'><%= icon %></i>
    """

  end
end
