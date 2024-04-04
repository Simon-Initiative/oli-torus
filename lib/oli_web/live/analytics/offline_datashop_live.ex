defmodule OliWeb.Analytics.OfflineDatashopLive do
  @moduledoc """
  LiveView implementation of datashop analytics view.
  """

  use OliWeb, :live_view

  def mount(_params, session, socket) do
    ctx = SessionContext.init(socket, session)

    socket =
      assign(socket,
        ctx: ctx,
        title: "Datashop Analytics"
      )

    {:ok, socket}
  end

  attr(:title, :string, default: "Datashop Analytics")

  def render(assigns) do
    ~H"""
    <p>
      <span class="text-2xl font-bold">Datashop Analytics</span>
    </p>
    """
  end

end
