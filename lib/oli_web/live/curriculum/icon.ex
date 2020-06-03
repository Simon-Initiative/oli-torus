defmodule OliWeb.Container.Icon do
  use Phoenix.LiveComponent

  alias OliWeb.Common.MaterialIcon

  def render(assigns) do
    case assigns.page.graded do
      true -> ~L"""
        <small>Assessment</small> <%= live_component @socket, MaterialIcon, icon: "check_box", category: "outlined", width: "16px" %>
        """
      false -> ~L"""
        <small>Page</small> <%= live_component @socket, MaterialIcon, icon: "assessment", category: "outlined", width: "16px" %>
        """
    end
  end
end
