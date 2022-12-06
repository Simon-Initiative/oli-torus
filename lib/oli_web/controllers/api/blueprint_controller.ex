defmodule OliWeb.Api.BlueprintController do
  @moduledoc tags: ["Blueprints Service"]
  @moduledoc """
  Endpoints to provide access to authoring blueprints
  """

  alias OpenApiSpex.Schema
  alias Oli.Authoring.Editing.Blueprint

  require Logger

  use OliWeb, :controller
  use OpenApiSpex.Controller

  defmodule BlueprintResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Blueprint",
      description: "A blueprint that can be inserted into content",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the blueprint"},
        description: %Schema{type: :string, description: "Short description of what it is"},
        icon: %Schema{type: :string, description: "A Material UI icon name to display in the UI"},
        content: %Schema{
          type: :string,
          description: "Array of content nodes to insert into the document"
        }
      },
      required: [:name, :description, :icon, :content],
      example: [
        %{
          "name" => "Theorem",
          "description" => "A theorem is a statement that is true under certain conditions",
          "icon" => "rate_review",
          "content" => %{
            "blueprint" => [
              %{"type" => "h1", "children" => [%{"text" => "Enter a statement here"}]}
            ]
          }
        }
      ]
    })
  end

  @doc parameters: [],
       responses: %{
         200 =>
           {"All Blueprints", "application/json",
            OliWeb.Api.BlueprintController.BlueprintResponse}
       }
  def index(conn, _attrs) do
    blueprints = Blueprint.list_blueprints()

    json(conn, %{
      "result" => "success",
      "rows" => Enum.map(blueprints, &serialize_blueprint/1)
    })
  end

  defp serialize_blueprint(%Blueprint{} = blueprint) do
    %{
      name: blueprint.name,
      description: blueprint.description,
      content: blueprint.content,
      icon: blueprint.icon
    }
  end
end
