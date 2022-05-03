defmodule OliWeb.ApiSpec do
  alias OpenApiSpex.{Info, OpenApi, Paths, Server, SecurityScheme, Components}
  alias OliWeb.{Endpoint, Router}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        # Populate the Server info from a phoenix endpoint
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "OLI",
        version: "1.0"
      },
      components: %Components{
        securitySchemes: %{
          "bearer-authorization" => %SecurityScheme{type: "http", scheme: "bearer"}
        }
      },

      # Populate the paths from a phoenix router
      paths: Paths.from_router(Router)
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end
