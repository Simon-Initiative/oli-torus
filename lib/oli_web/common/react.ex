defmodule OliWeb.Common.React do
  # use Phoenix.Component

  import PhoenixLiveReact

  def component(%{is_liveview: true}, name, props),
    do: live_react_component(name, props)

  def component(_, name, props),
    do: ReactPhoenix.ClientSide.react_component(name, props)

  def component(%{is_liveview: true}, name, props, opts),
    do: live_react_component(name, props, opts)

  def component(_, name, props, opts),
    do: ReactPhoenix.ClientSide.react_component(name, props, opts)
end
