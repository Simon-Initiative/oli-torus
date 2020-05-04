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
end
