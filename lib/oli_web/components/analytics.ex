defmodule OliWeb.Components.Analytics do
  @moduledoc "Shared head installation for opted-in, covered root layouts."
  use Phoenix.Component

  alias OliWeb.Analytics

  attr :conn, Plug.Conn, required: true

  @doc "Loads the single analytics writer before other head content, with escaped configuration."
  def gtm_head(assigns) do
    assigns = assign(assigns, :config, head_config(assigns.conn))

    ~H"""
    <script
      :if={@config}
      id="torus-analytics"
      src={OliWeb.Router.Helpers.static_path(@conn, "/js/analytics.js")}
      data-config={@config}
    >
    </script>
    """
  end

  defp head_config(conn) do
    with true <- Analytics.enabled?(),
         %{} = context <- Analytics.context_for_conn(conn) do
      config = Application.get_env(:oli, :analytics, [])

      Jason.encode!(%{
        container_id: config[:gtm_container_id],
        auth: config[:gtm_auth],
        preview: config[:gtm_preview],
        context: context
      })
    else
      _ -> nil
    end
  end
end
