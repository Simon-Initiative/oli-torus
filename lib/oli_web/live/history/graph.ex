defmodule OliWeb.RevisionHistory.Graph do
  use Phoenix.LiveComponent

  def update(assigns, socket) do
    root_node = Map.get(assigns.tree, assigns.root.id)
    built = OliWeb.RevisionHistory.ReingoldTilford.build(root_node, assigns.tree)

    nodes = OliWeb.RevisionHistory.ReingoldTilford.nodes(built)
    lines = OliWeb.RevisionHistory.ReingoldTilford.lines(built)

    {:ok,
     assign(socket,
       project: assigns.project,
       nodes: nodes,
       lines: lines,
       initial_size: 400,
       selected: assigns.selected
     )}
  end

  def render(assigns) do
    assigns =
      assigns
      |> assign(:active_current_class, fn n ->
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
      end)

    ~H"""
    <svg
      id="graph"
      style="cursor: grab;"
      height="150"
      width="100%"
      phx-hook="GraphNavigation"
      class="revision-tree rounded"
    >
      <defs>
        <marker
          id="arrowhead"
          class="arrowhead"
          markerWidth="10"
          markerHeight="7"
          refX="0"
          refY="3.5"
          orient="auto"
        >
          <polygon points="0 0, 10 3.5, 0 7" />
        </marker>
      </defs>
      <g id="panner" transform="translate(0,60) scale(1.0)">
        <g id="all_nodes">
          <%= for node <- @nodes do %>
            <rect
              id={rect_id(node.label)}
              x={node.x}
              y={node.y}
              rx="8"
              ry="8"
              width={node.width}
              height={node.height}
              class={"node #{@active_current_class.(node)}"}
              phx-click={
                Phoenix.LiveView.JS.push("select",
                  value: %{rev: "#{node.value.revision.id}"},
                  page_loading: true
                )
              }
            />
            <text
              id={node.label}
              class={"tree-node-text #{@active_current_class.(node)}"}
              text-anchor="middle"
              x={"#{node.x + div(node.width, 2)}"}
              y={"#{node.y + div(node.height, 2)}"}
              dominant-baseline="central"
            >
              {node.label}
            </text>
          <% end %>
          <%= for {line, index} <- Enum.with_index(@lines) do %>
            <line
              id={line_id(index)}
              x1={line.x1}
              y1={line.y1}
              x2={line.x2}
              y2={line.y2}
              class="line"
              marker-end="url(#arrowhead)"
            />
          <% end %>
        </g>
      </g>
    </svg>
    """
  end

  defp rect_id(label) do
    "#{label}_rect"
  end

  defp line_id(index) do
    "#{index}_line"
  end
end
