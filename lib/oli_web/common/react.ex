defmodule OliWeb.Common.React do
  @moduledoc """
  React component wrappers. It wraps the `ReactPhoenix.ClientSide.react_component` function and the
  `PhoenixLiveReact.live_react_component` function to provide a single `component` function that can be used in non LiveView
  and LiveViews respectively (that is why the OliWeb.Common.SessionContext (@ctx) is passed as first argument, to distinguish liveview from non-liveview)

  ## Usage in a template

  <%= React.component(@ctx, "Components.MyComponent", %{name: "Bob"}, id: "my-component-1") %>

  Remember to import and register the component in assets/src/apps/Components.tsx
  """

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
