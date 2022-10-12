defmodule OliWeb.Common.MaterialIcon do
  use Phoenix.LiveComponent

  def render(assigns) do
    assigns =
      assigns
      |> assign(
        :category,
        if assigns.category === nil do
          ""
        else
          "-" <> assigns.category
        end
      )

    ~H"""
    <i style={"width: #{@width}"} class={"material-icons#{@category} icon"}><%= @icon %></i>
    """
  end
end
