defmodule OliWeb.ApiSchemas do
  alias OpenApiSpex.Schema

  defmodule CreationResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Update response",
      description: "The response to a successful document update request",
      type: :object,
      properties: %{
        result: %Schema{type: :string, description: "The literal value of 'success'"},
        resourceId: %Schema{
          type: :integer,
          description: "The identifier for the newly created resource"
        }
      },
      required: [:result, :resource_id],
      example: %{
        "result" => "success",
        "resourceId" => 239_820
      }
    })
  end

  defmodule UpdateResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Update response",
      description: "The response to a successful document update request",
      type: :object,
      properties: %{
        result: %Schema{type: :string, description: "The literal value of 'success'"}
      },
      required: [:result],
      example: %{
        "result" => "success"
      }
    })
  end
end
