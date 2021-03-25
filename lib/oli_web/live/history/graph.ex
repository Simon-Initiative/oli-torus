defmodule OliWeb.RevisionHistory.Graph do
  use Phoenix.LiveComponent
  alias OliWeb.RevisionHistory.Node

  def render(assigns) do

    size = length(assigns.revisions)

    ~L"""
    <svg id="graph" viewBox="0 0 1000 100"
      style="cursor: grab;"
      height="100" width="100%" phx-hook="GraphNavigation">
      <style>
        .small { font: normal 12px sans-serif; }
      </style>
      <g id="panner">
        <g id="all_nodes" phx-update="append"
          transform="translate(<%= ((-@initial_size / 2) * Node.get_node_width()) %>, 0)">
          <%= for {rev, i} <- Enum.with_index(@revisions) do %>
            <%= live_component @socket, Node,
              index: i,
              revision: rev,
              selected?: rev == @selected,
              show_line?: i != (size - 1) %>
          <% end %>
        </g>
      </g>
    </svg>
    """
  end

  def render(assigns) do
    ~L"""
      <svg id="graph" viewBox="0 0 1000 100"
        style="cursor: grab;"
        height="100" width="100%" phx-hook="GraphNavigation">
        <style>
          .small { font: normal 12px sans-serif; }
        </style>
        <g id="panner">
          <g id="all_nodes" phx-update="append"
            transform="translate(<%= ((-@initial_size / 2) * Node.get_node_width()) %>, 0)">
            <%= for node <- @nodes do %>
              <rect x="<%= node.x %>" y="<%= node.y %>" rx="10" ry="10" width="<%= node.width %>" height="<%= node.height %>"
              class="node" phx-click="show_info" phx-value-info="<%= node_encoded_pid(node.value) %>" phx-page-loading />
              <text class="tree-node-text" x="<%= node.x + 10 %>" y="<%= node.y + div(node.height, 2) %>" dominant-baseline="central">
                <%= node.label %>
              </text>
            <% end %>
            <%= for line <- @lines do %>
              <line x1="<%= line.x1 %>" y1="<%= line.y1 %>" x2="<%= line.x2 %>" y2="<%= line.y2 %>" class="line" />
            <% end %>
          </g>
        </g>
      </svg>
    """
  end

end
