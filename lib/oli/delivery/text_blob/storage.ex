defmodule Oli.Delivery.TextBlob.Storage do

  alias ExAws.S3
  alias Oli.HTTP

  @moduledoc """
  A module for the raw text blob storage read and write operations.

  This module is designed to provide a simple interface for storing and retrieving
  potentially large text blobs in and out of files in S3.
  """

  @doc """
  Writes an arbitrary text blob to storage, associated with a unique key.
  The key can be any string that uniquely identifies the blob, and the text_blob
  is the content to be stored.

  Returns `:ok` on success or an error tuple on failure.
  """
  def write(key, text_blob) do

    bucket_name = Application.fetch_env!(:oli, :blob_storage)[:bucket_name]

    case S3.put_object(bucket_name, key, text_blob, [{:acl, :public_read}])
    |> HTTP.aws().request() do
      {:ok, %{status_code: 200}} ->
        :ok
      {_, payload} ->
        {:error, payload}
    end

  end

  @doc """
  Reads a text blob from storage using the provided key.
  If the key exists, it returns `{:ok, text_blob}` where `text_blob` is the content
  associated with the key. If the key does not exist, it returns the specified
  `not_found_value`.
  """
  def read(key, default_value) do

    bucket_name = Application.fetch_env!(:oli, :blob_storage)[:bucket_name]

    case S3.put_object(bucket_name, key, text_blob, [{:acl, :public_read}])
    |> HTTP.aws().request() do
      {:ok, %{status_code: 200, body: text_blob}} ->
        {:ok, text_blob}
      {_, _} ->
        default_value
    end

  end

end
