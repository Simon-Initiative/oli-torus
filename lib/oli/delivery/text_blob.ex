defmodule Oli.Delivery.TextBlob do
  @moduledoc """
  A module for text blob storage, allowing for the storage and retrieval of text blobs
  keyed off of either a globally unique identifier or a user scoped unique identifier.
  """

  @doc """
  Reads a text blob from a user scoped key.

  Returns {:ok, text_blob} if the blob exists, or {:ok, default_value}
  if it does not.  An error tuple is returned if the read operation fails.
  """
  def read(user, key, default_value) do
    build_user_key(user, key)
    |> read(default_value)
  end

  @doc """
  Reads a text blob from a globally unique key.

  Returns {:ok, text_blob} if the blob exists, or {:ok, default_value}
  if it does not.  An error tuple is returned if the read operation fails.
  """
  def read(key, default_value) do
    Oli.Delivery.TextBlob.Storage.read(key, default_value)
  end

  @doc """
  Writes a text blob to a user scoped key.
  Returns :ok on success, or an error tuple on failure.
  """
  def write(user, key, text_blob) do
    build_user_key(user, key)
    |> write(text_blob)
  end

  @doc """
  Writes a text blob to a globally unique key.
  Returns :ok on success, or an error tuple on failure.
  """
  def write(key, text_blob) do
    Oli.Delivery.TextBlob.Storage.write(key, text_blob)
  end

  defp build_user_key(user, key) do
    case user.sub do
      nil -> "#{user.id}/#{key}"
      _ -> "#{user.sub}/#{key}"
    end
  end
end
