defmodule OliWeb.DevController do
  use OliWeb, :controller

  alias Oli.Utils.FlameGraph

  def flame_graphs(conn, _params) do
    flame_graphs =
      FlameGraph.list()
      |> Enum.map(&FlameGraph.to_svg(&1))

    render(conn, "flame_graphs.html", flame_graphs: flame_graphs)
  end
end
