defmodule OliWeb.Pow.UserRoutes do
  use Pow.Phoenix.Routes

  @impl true
  def path_for(conn, plug, _verb, vars \\ [], query_params \\ []) do
    # plug = Module.concat(["UserPow", verb])
    Pow.Phoenix.Routes.path_for(conn, plug, vars, query_params)
  end

  @impl true
  def url_for(conn, plug, _verb, vars \\ [], query_params \\ []) do
    # plug = Module.concat(["UserPow", verb])
    Pow.Phoenix.Routes.url_for(conn, plug, vars, query_params)
  end
end
