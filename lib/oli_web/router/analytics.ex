defmodule OliWeb.Router.Analytics do

  defmacro analytics_routes(path, opts \\ []) do

    scope =
      quote bind_quoted: binding() do
        scope path, alias: false, as: false do

          pipe_through([:browser, :authoring_protected])

          live("/datashop", Analytics.OfflineDatashopLive)

        end
      end

    # TODO: Remove check once we require Phoenix v1.7
    if Code.ensure_loaded?(Phoenix.VerifiedRoutes) do
      quote do
        unquote(scope)
      end
    else
      scope
    end
  end

end
