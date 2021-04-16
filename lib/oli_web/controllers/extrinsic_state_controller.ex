defmodule OliWeb.ExtrinsicStateController do
  @moduledoc """
  Provides user state service endpoints for extrinsic state.
  """
  use OliWeb, :controller
  use OpenApiSpex.Controller

  alias Oli.Delivery.ExtrinsicState

  alias OpenApiSpex.Schema

  @moduledoc tags: ["User State Service: Extrinsic State"]

  @global_parameters []

  @section_parameters [
    section_slug: [
      in: :url,
      schema: %Schema{type: :string},
      required: true,
      description: "The course section identifier"
    ]
  ]

  @keys [
    keys: [
      in: :query,
      schema: %Schema{type: :list},
      required: true,
      description: "A collection of key names"
    ]
  ]

  defmodule ExtrinsicReadResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Response from reading a collection of key-values",
      description: "The read top-level keys and their nested values",
      type: :object,
      required: [],
      example: %{
        "userActionDone" => true
      }
    })
  end

  defmodule ExtrinsicUpsertDeleteResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Upsert Delete Response",
      description: "Response from updating or deleting a collection of key-values",
      type: :object,
      properties: %{
        result: %Schema{type: :string, description: "Success"}
      },
      required: [:result],
      example: %{
        "result" => "success"
      }
    })
  end

  defmodule ExtrinsicUpsertBody do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Upsert action body",
      description: "The request body representing the key values to insert or update",
      type: :object,
      properties: %{},
      required: [:response],
      example: %{
        "response" => %{"selected" => "A"}
      }
    })
  end

  @doc """
  Reads state from the user's global context. State exists as key-value pairs. The
  values can be nested JSON structures or simple scalar attributes.

  The optional `keys` query parameter allows one to read a subset of the top-level
  keys present in this context.  Omitting this parameter returns all top-level keys.

  An example request, showing how to structure the keys parameter to contain the key names
  "one", "two" and "three":

  ```
  /api/v1/state?keys[]=one&keys[]=two&keys=three
  ```

  """
  @doc parameters: @global_parameters,
       responses: %{
         200 => {"Update Response", "application/json", ExtrinsicReadResponse}
       }
  def read_global(conn, params) do
    user = conn.assigns.current_user

    keys =
      case Map.get(params, "keys") do
        nil -> nil
        k -> MapSet.new(k)
      end

    case ExtrinsicState.read_global(user.id, keys) do
      {:ok, state} ->
        json(conn, state)

      _ ->
        error(conn, 404, "not found")
    end
  end

  @doc """
  Inserts or updates top-level keys into the user's global context.
  """
  @doc parameters: @global_parameters,
       request_body: {"Global Upsert", "application/json", ExtrinsicUpsertBody, required: true},
       responses: %{
         200 => {"Update Response", "application/json", ExtrinsicUpsertDeleteResponse}
       }
  def upsert_global(conn, key_values) do
    user = conn.assigns.current_user

    case ExtrinsicState.upsert_global(user.id, key_values) do
      {:ok, _} ->
        json(conn, %{"result" => "success"})

      _ ->
        error(conn, 404, "not found")
    end
  end

  @doc """
  Deletes one or more keys from a user's global context.

  An example request, showing how to structure the keys parameter to contain the key names
  "one", "two" and "three":

  ```
  /api/v1/state?keys[]=one&keys[]=two&keys=three
  ```
  """
  @doc parameters: @global_parameters ++ @keys,
       responses: %{
         200 => {"Delete Response", "application/json", ExtrinsicUpsertDeleteResponse}
       }
  def delete_global(conn, params) do
    user = conn.assigns.current_user

    case Map.get(params, "keys") do
      nil ->
        error(conn, 400, "missing keyspec")

      k ->
        case ExtrinsicState.delete_global(user.id, MapSet.new(k)) do
          {:ok, _} ->
            json(conn, %{"result" => "success"})

          _ ->
            error(conn, 404, "not found")
        end
    end
  end

  @doc """
  Reads state from the section context for a particular section for this user.

  State exists as key-value pairs. The
  values can be nested JSON structures or simple scalar attributes.

  The optional `keys` query parameter allows one to read a subset of the top-level
  keys present in this context.  Omitting this parameter returns all top-level keys.

  An example request, showing how to structure the keys parameter to contain the key names
  "one", "two" and "three":

  ```
  /api/v1/state/course/:section_slug?keys[]=one&keys[]=two&keys=three
  ```

  """
  @doc parameters: @section_parameters,
       responses: %{
         200 => {"Update Response", "application/json", ExtrinsicReadResponse}
       }
  def read_section(conn, %{"section_slug" => section_slug} = params) do
    user = conn.assigns.current_user

    keys =
      case Map.get(params, "keys") do
        nil -> nil
        k -> MapSet.new(k)
      end

    case ExtrinsicState.read_section(user.id, section_slug, keys) do
      {:ok, state} ->
        json(conn, state)

      _ ->
        error(conn, 404, "not found")
    end
  end

  @doc """
  Inserts or updates top-level keys into a section specific context for the user.
  """
  @doc parameters: @section_parameters,
       request_body: {"Section Upsert", "application/json", ExtrinsicUpsertBody, required: true},
       responses: %{
         200 => {"Update Response", "application/json", ExtrinsicUpsertDeleteResponse}
       }
  def upsert_section(%Plug.Conn{body_params: key_values} = conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user

    case ExtrinsicState.upsert_section(user.id, section_slug, key_values) do
      {:ok, _} ->
        json(conn, %{"result" => "success"})

      _ ->
        error(conn, 404, "not found")
    end
  end

  @doc """
  Deletes one or more keys from a section specific context for the user.

  An example request, showing how to structure the keys parameter to contain the key names
  "one", "two" and "three":

  ```
  /api/v1/state/course/:section_slug?keys[]=one&keys[]=two&keys=three
  ```
  """
  @doc parameters: @section_parameters ++ @keys,
       responses: %{
         200 => {"Delete Response", "application/json", ExtrinsicUpsertDeleteResponse}
       }
  def delete_section(conn, %{"section_slug" => section_slug} = params) do
    user = conn.assigns.current_user

    case Map.get(params, "keys") do
      nil ->
        error(conn, 400, "missing keyspec")

      k ->
        case ExtrinsicState.delete_section(user.id, section_slug, MapSet.new(k)) do
          {:ok, _} ->
            json(conn, %{"result" => "success"})

          _ ->
            error(conn, 404, "not found")
        end
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end
