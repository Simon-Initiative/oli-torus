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

  def create(conn, %{"upload" => upload}) do

    if is_valid_api_key?(conn, &Oli.Interop.validate_for_registration/1) do
      expected_namespace = get_api_namespace(conn)

      case Activities.register_from_bundle(upload.path, expected_namespace) do
        {:ok, _} -> json(conn, %{result: :success})
        {:error, e} ->
          error(conn, 400, "error")
      end
    else
      error(conn, 400, "invalid key")

    end
  end

end
