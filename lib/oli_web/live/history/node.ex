defmodule OliWeb.RevisionHistory.Node do
  use Phoenix.LiveComponent

  def get_node_width(), do: 70

  def render(assigns) do

    width = 40
    height = 26
    gap = 30

    {text_style, rect_style} = case assigns.selected? do
      true -> {"", "stroke-width:2; stroke:blue;"}
      false -> {"cursor: pointer;", "cursor: pointer;"}
    end

    e = width + gap

    ~L"""
    <g transform="translate(<%= @index * (width + gap) %>, 50)">
      <%= if @show_line? do %>
        <line x1="<%= width %>" x2="<%=(width + gap) %>" y1="<%= (height/2) %>" y2="<%= (height/2) %>" stroke="black"/>
        <polygon points="<%=e%>,<%=(height/2)%> <%=e-4%>,<%=(height/2)-2%> <%=e-4%>,<%=(height/2)+2%> " style="fill:black;" />
      <% end %>
      <g phx-click="select" phx-value-rev="<%= @revision.id %>">
        <rect style="<%=rect_style%>" id="node-<%= @revision.id %>" x="0" y="0" width="<%= width %>" height="<%= height %>" fill="lightblue">
          <title>
            <%= @revision.title %>
          </title>
        </rect>
        <text style="<%=text_style%>"
            x="<%= (width/2) %>" y="<%= (height/2) %>"
            class="small"
            alignment-baseline="middle"
            text-anchor="middle">
            <%= @revision.id %>
        </text>
      </g>
    </g>
    """
  end
end
