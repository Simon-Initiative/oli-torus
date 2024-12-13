defmodule Oli.Plugs.RequireIndependentInstructor do
  import Plug.Conn
  alias Oli.Delivery.Sections

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = conn.assigns[:current_user]

    if Sections.is_independent_instructor?(current_user) do
      conn
    else
      conn
      |> resp(403, "Forbidden")
      |> halt()
    end
  end
end
