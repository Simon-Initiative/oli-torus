defmodule OliWeb.Common.React do
  @moduledoc """
  React component wrappers. It wraps the `ReactPhoenix.ClientSide.react_component` function and the
  `PhoenixLiveReact.live_react_component` function to provide a single `component` function that can be used in non LiveView
  and LiveViews respectively (that is why the OliWeb.Common.SessionContext (@ctx) is passed as first argument, to distinguish liveview from non-liveview)

  ## Usage in a template

  <%= React.component(@ctx, "Components.MyComponent", %{name: "Bob"}, id: "my-component-1") %>

  Rendering contexts may set `render_opts.react_component_id_prefix` to scope component IDs when
  the same rendered content can appear more than once in a LiveView.

  Remember to import and register the component in assets/src/apps/Components.tsx
  """

  import PhoenixLiveReact

  def component(%{is_liveview: true}, name, props),
    do: live_react_component(name, props)

  def component(_, name, props),
    do: ReactPhoenix.ClientSide.react_component(name, props)

  def component(%{is_liveview: true} = context, name, props, opts),
    do: live_react_component(name, props, prefix_component_id(context, opts))

  def component(context, name, props, opts),
    do: ReactPhoenix.ClientSide.react_component(name, props, prefix_component_id(context, opts))

  defp prefix_component_id(context, opts) do
    with %{render_opts: render_opts} when is_map(render_opts) <- context,
         prefix when is_binary(prefix) and prefix != "" <-
           Map.get(render_opts, :react_component_id_prefix),
         id when is_binary(id) and id != "" <- Keyword.get(opts, :id) do
      Keyword.put(opts, :id, "#{prefix}-#{id}")
    else
      _ -> opts
    end
  end
end
