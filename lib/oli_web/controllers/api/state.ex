defmodule OliWeb.Api.State do
  import Phoenix.Controller
  import OliWeb.Api.Helpers
  alias OpenApiSpex.Schema

  defmodule ReadResponse do
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

  defmodule UpsertDeleteResponse do
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

  defmodule UpsertBody do
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

  def read(conn, params, reader) do
    user = conn.assigns.current_user

    keys =
      case Map.get(params, "keys") do
        nil -> nil
        k -> MapSet.new(k)
      end

    case reader.(%{user: user, keys: keys}) do
      {:ok, state} ->
        json(conn, state)

      _ ->
        error(conn, 404, "not found")
    end
  end

  def upsert(%Plug.Conn{body_params: key_values} = conn, _, writer) do
    user = conn.assigns.current_user

    case writer.(%{user: user, key_values: key_values}) do
      {:ok, _} ->
        json(conn, %{"result" => "success"})

      _ ->
        error(conn, 404, "not found")
    end
  end

  def delete(conn, params, deleter) do
    user = conn.assigns.current_user

    case Map.get(params, "keys") do
      nil ->
        error(conn, 400, "missing keyspec")

      k ->
        case deleter.(%{user: user, keys: MapSet.new(k)}) do
          {:ok, _} ->
            json(conn, %{"result" => "success"})

          _ ->
            error(conn, 404, "not found")
        end
    end
  end
end
