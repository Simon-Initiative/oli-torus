defmodule OliWeb.RevisionHistory.Graph do
  use Phoenix.LiveComponent

  def update(assigns, socket) do

    root_node = Map.get(assigns.tree, assigns.root.id)
    built = OliWeb.RevisionHistory.ReingoldTilford.build(root_node, assigns.tree)

    nodes = OliWeb.RevisionHistory.ReingoldTilford.nodes(built)
    lines = OliWeb.RevisionHistory.ReingoldTilford.lines(built)

    {:ok, assign(socket, project: assigns.project, nodes: nodes, lines: lines, initial_size: 400, selected: assigns.selected)}

  end

  def render(assigns) do

    node_class = fn n ->

      "node " <>
        if n.value.project_id == assigns.project.id do
          " current"
        else
          ""
        end <>
        if n.value.revision.id == assigns.selected.id do
          " active"
        else
          ""
        end
    end

    ~L"""
      <svg id="graph"
        style="cursor: grab;"
        height="400" width="100%" phx-hook="GraphNavigation" class="revision-tree">
        <g id="panner">
          <g id="all_nodes" phx-update="append">
            <%= for node <- @nodes do %>
              <rect x="<%= node.x %>" y="<%= node.y %>" rx="8" ry="8" width="<%= node.width %>" height="<%= node.height %>"
                class="<%= node_class.(node) %>" phx-click="select" phx-value-rev="<%= node.value.revision.id %>" phx-page-loading />
              <text class="tree-node-text" text-anchor="middle" x="<%= node.x + div(node.width, 2) %>" y="<%= node.y + div(node.height, 2) %>" dominant-baseline="central">
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
