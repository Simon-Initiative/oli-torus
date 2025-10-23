defmodule OliWeb.Dev.IconsLive do
  @moduledoc """
  A only dev access liveview to show all icons available in OliWeb.Icons

  This should improve the developer experience
  """

  use OliWeb, :live_view

  alias OliWeb.Icons
  alias OliWeb.Common.React

  def mount(_params, _session, socket) do
    icons =
      Icons.module_info(:exports)
      |> Keyword.keys()
      |> Enum.filter(&(&1 not in [:__info__, :__components__, :module_info]))

    {:ok,
     assign(socket, icons: icons, hide_header: true, hide_footer: true, ctx: %{is_liveview: true})}
  end

  def render(assigns) do
    ~H"""
    <div class="p-10">
      <div class="flex flex-col mb-4">
        <div class="flex justify-between items-center h-20">
          <h1 class="text-3xl">Icons</h1>
          {React.component(@ctx, "Components.DarkModeSelector", %{showLabels: false},
            id: "dark_mode_selector"
          )}
        </div>
        <p class="text-lg">
          This page renders all icons defined at <code>OliWeb.Icons</code>.
        </p>
        <p class="text-lg">
          Take into account that the "base" version of the icon is rendered, and does not show any variations the icon may have (by passing an attr for example)
        </p>
      </div>
      <div class="grid grid-cols-5 gap-10 p-10 justify-center">
        <div :for={icon_name <- @icons} class="flex flex-col gap-4">
          <span>{icon_name}</span>
          <div class="w-min min-w-[48px] h-12 flex justify-center items-center">
            <span>{apply(OliWeb.Icons, icon_name, [%{}])}</span>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
