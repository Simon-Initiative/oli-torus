defmodule OliWeb.Api.GlobalStateController do
  @moduledoc """
  Provides user state service endpoints for extrinsic state.
  """
  use OliWeb, :controller
  use OpenApiSpex.Controller

  alias Oli.Delivery.ExtrinsicState
  alias OliWeb.Api.State

  alias OpenApiSpex.Schema

  @moduledoc tags: ["User State Service: Extrinsic State"]

  @global_parameters []

  @keys [
    keys: [
      in: :query,
      schema: %Schema{type: :list},
      required: true,
      description: "A collection of key names"
    ]
  ]

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
         200 => {"Update Response", "application/json", State.ReadResponse}
       }
  def read(conn, params) do
    State.read(conn, params, fn %{user: user, keys: keys} ->
      ExtrinsicState.read_global(user.id, keys)
    end)
  end

  @doc """
  Inserts or updates top-level keys into the user's global context.
  """
  @doc parameters: @global_parameters,
       request_body: {"Global Upsert", "application/json", State.UpsertBody, required: true},
       responses: %{
         200 => {"Update Response", "application/json", State.UpsertDeleteResponse}
       }
  def upsert(conn, params) do
    IO.inspect("upsert")

    State.upsert(conn, params, fn %{user: user, key_values: key_values} ->
      ExtrinsicState.upsert_global(user.id, key_values)
    end)
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
         200 => {"Delete Response", "application/json", State.UpsertDeleteResponse}
       }
  def delete(conn, params) do
    State.delete(conn, params, fn %{user: user, keys: keys} ->
      ExtrinsicState.delete_global(user.id, keys)
    end)
  end
end
