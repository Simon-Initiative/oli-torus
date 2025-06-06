defmodule OliWeb.Api.BlobStorageController do

  use OliWeb, :controller

  alias Oli.Delivery.TextBlob
  require Logger

  @moduledoc """
  Provides endpoints for reading and writing text blobs, both for user scoped
  and globally scoped keys.

  While this data is stored as text blobs, it is known that the content
  being stored through this endpoint is actually stringified JSON objects (from
  the adaptive page client-side implementation). This controller is designed to
  provide a simple interface for reading and writing these blobs, with appropriate
  default "JSON as string" values and error handling.

  All of this exists to support the storing and retrieving of large JSON objects
  without the need to serialize and deserialize them in the application layer
  and without the need to store them in the database.
  """


  @doc """
  Reads a text blob from a user scoped key.
  """
  def read_user_key(conn, params) do
    read(conn, fn -> TextBlob.read(conn.assigns.current_user, params["key"], "{}") end)
  end


  @doc """
  Reads a text blob from storage using the provided key.
  """
  def read_key(conn, params) do
    read(conn, fn -> TextBlob.read(params["key"], "{}") end)
  end

  @doc """
  Writes a text blob to a user scoped key.
  """
  def write_user_key(conn, params) do
    write(conn, fn text ->
      TextBlob.write(conn.assigns.current_user, params["key"], text)
    end)
  end

  @doc """
  Writes a text blob from storage using the provided guid as the key.
  """
  def write_key(conn, params) do
    write(conn, fn text ->
      TextBlob.write(params["key"], text)
    end)
  end

  defp write(conn, write_fn) do

    {:ok, text, _conn} = Plug.Conn.read_body(conn)

    case write_fn.(text) do
      :ok ->
        text(conn, "success")
      {:error, reason} ->
        Logger.error("Failed to write blob with key #{key}: #{inspect(reason)}")
        error(conn, 500, reason)
    end

  end

  defp read(conn, read_fn) do
    case read_fn.() do
      {:ok, result} ->
        text(conn, result)
      {:error, reason} ->
        error(conn, 500, reason)
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end

end
