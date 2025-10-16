defmodule Oli.GoogleDocs.ClientTest do
  use ExUnit.Case, async: true

  import Mox

  alias HTTPoison.Response
  alias Oli.GoogleDocs.Client
  alias Oli.GoogleDocsImport.TestHelpers
  alias Oli.Test.MockHTTP

  @retry_opts [retry_delay_ms: 0]

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "fetch_markdown returns markdown body for a valid FILE_ID" do
    file_id = "1AbcdefGhIJ"
    TestHelpers.expect_markdown_fetch(file_id, :baseline)

    assert {:ok, result} = Client.fetch_markdown(file_id)
    assert result.file_id == file_id
    assert result.url == TestHelpers.markdown_export_url(file_id)
    assert String.contains?(result.body, "# Getting Started with Cloud Security")
    assert result.bytes == byte_size(result.body)
    assert String.starts_with?(result.content_type, "text/markdown")
  end

  test "rejects blank or malformed FILE_ID values" do
    assert {:error, {:invalid_file_id, :blank}} = Client.fetch_markdown("   ")

    assert {:error, {:invalid_file_id, :format}} =
             Client.fetch_markdown("https://example.com/doc")

    assert {:error, {:invalid_file_id, :format}} = Client.fetch_markdown("bad id")
    assert {:error, {:invalid_file_id, :not_binary}} = Client.fetch_markdown(123)
  end

  test "enforces size limit using max_bytes override for testing" do
    file_id = "1SmallCapTest"
    TestHelpers.expect_markdown_fetch(file_id, :baseline)

    assert {:error, {:body_too_large, %{limit: 200, bytes: bytes}}} =
             Client.fetch_markdown(file_id, max_bytes: 200)

    assert bytes > 200
  end

  test "retries once on 5xx and succeeds on second attempt" do
    file_id = "1RetryOnFive"
    url = TestHelpers.markdown_export_url(file_id)

    expect(MockHTTP, :get, fn ^url, _headers, _opts ->
      {:ok, %Response{status_code: 502, headers: [], body: "bad gateway"}}
    end)

    TestHelpers.expect_markdown_fetch(file_id, :baseline)

    assert {:ok, %{file_id: ^file_id}} = Client.fetch_markdown(file_id, @retry_opts)
  end

  test "fails when all attempts return 5xx" do
    file_id = "1AlwaysBad"
    url = TestHelpers.markdown_export_url(file_id)

    expect(MockHTTP, :get, 2, fn ^url, _headers, _opts ->
      {:ok, %Response{status_code: 503, headers: [], body: "service unavailable"}}
    end)

    assert {:error, {:http_status, 503, %Response{status_code: 503, body: nil}}} =
             Client.fetch_markdown(file_id, @retry_opts)
  end

  test "retries once on timeout errors" do
    file_id = "1TimeoutRetry"
    url = TestHelpers.markdown_export_url(file_id)
    error = %HTTPoison.Error{id: nil, reason: :timeout}

    expect(MockHTTP, :get, fn ^url, _headers, _opts -> {:error, error} end)
    TestHelpers.expect_markdown_fetch(file_id, :baseline)

    assert {:ok, %{file_id: ^file_id}} = Client.fetch_markdown(file_id, @retry_opts)
  end

  test "returns error on non-retriable HTTP status" do
    file_id = "1NotFoundX0"
    url = TestHelpers.markdown_export_url(file_id)

    expect(MockHTTP, :get, fn ^url, _headers, _opts ->
      {:ok, %Response{status_code: 404, headers: [], body: "not found"}}
    end)

    assert {:error, {:http_status, 404, %Response{status_code: 404, body: nil}}} =
             Client.fetch_markdown(file_id, retry_delay_ms: 0)
  end
end
