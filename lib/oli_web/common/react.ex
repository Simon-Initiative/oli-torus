defmodule OliWeb.Common.React do
  # use Phoenix.Component

  import PhoenixLiveReact

  alias OliWeb.Common.SessionContext

  def component(%SessionContext{is_liveview: true}, name, props, opts),
    do: live_react_component(name, props, opts)

  def component(%SessionContext{is_liveview: false}, name, props, opts),
    do: ReactPhoenix.ClientSide.react_component(name, props, opts)
end
