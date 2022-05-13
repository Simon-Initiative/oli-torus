defmodule OliWeb.Api.ActivityRegistrationController do
  use OliWeb, :controller
  use OpenApiSpex.Controller

  alias Oli.Activities
  import OliWeb.Api.Helpers

  @moduledoc tags: ["Activity Registration Service"]

  @moduledoc """
  The activity registration allows new activities to be registered with the system, and
  existing ones to have their implementations updated.
  """

  alias OpenApiSpex.Schema

  defmodule RegistrationResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Activity registration response",
      description: "The response for an activity registration operation",
      type: :object,
      properties: %{
        success: %Schema{type: :string, description: "true"}
      },
      required: [:success],
      example: %{
        "success" => "true"
      }
    })
  end

  defmodule RegistrationUploadBody do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Activity bundle upload body",
      description: "The request body for uploading an activity bundle for registration",
      type: :object,
      properties: %{
        upload: %Schema{
          type: :object,
          description: "The form data"
        }
      },
      required: [:upload]
    })
  end

  @doc """
  Uploads an activity bundle for registation or update.
  """
  @doc parameters: [],
       security: [%{"bearer-authorization" => []}],
       request_body:
         {"File upload", "multipart/form-data",
          OliWeb.Api.ActivityRegistrationController.RegistrationUploadBody, required: true},
       responses: %{
         200 =>
           {"Retrieval Response", "application/json",
            OliWeb.Api.ActivityRegistrationController.RegistrationResponse}
       }

  def create(conn, %{"upload" => upload}) do
    if is_valid_api_key?(conn, &Oli.Interop.validate_for_registration/1) do
      expected_namespace = get_api_namespace(conn)

      case Activities.register_from_bundle(upload.path, expected_namespace) do
        {:ok, _} ->
          json(conn, %{result: :success})

        e ->
          error(conn, 400, Kernel.inspect(e))
      end
    else
      error(conn, 400, "invalid key")
    end
  end
end
