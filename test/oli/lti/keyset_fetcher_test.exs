defmodule Oli.Lti.KeysetFetcherTest do
  use ExUnit.Case, async: false

  import Mox

  alias Oli.Lti.KeysetCache
  alias Oli.Lti.KeysetFetcher

  setup :verify_on_exit!

  @test_url "https://example.com/jwks"
  @test_key %{
    "kty" => "RSA",
    "kid" => "test-key-1",
    "use" => "sig",
    "n" =>
      "0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4cbbfAAtVT86zwu1RK7aPFFxuhDR1L6tSoc_BJECPebWKRXjBZCiFV4n3oknjhMstn64tZ_2W-5JsGY4Hc5n9yBXArwl93lqt7_RN5w6Cf0h4QyQ5v-65YGjQR0_FDW2QvzqY368QQMicAtaSqzs8KJZgnYb9c7d0zgdAZHzu6qMQvRL5hajrn1n91CbOpbISD08qNLyrdkt-bFTWhAI4vMQFh6WeZu0fM4lFd2NcRwr3XPksINHaQ-G_xBniIqbw0Ls1jF44-csFCur-kEgU8awapJzKnqDKgw",
    "e" => "AQAB"
  }

  setup do
    KeysetCache.clear_cache()
    :ok
  end

  describe "fetch_and_cache/1" do
    test "fetches JWKS, caches it, and returns normalized metadata" do
      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [@test_key]}),
           headers: [{"cache-control", "public, max-age=123"}]
         }}
      end)

      assert {:ok, result} = KeysetFetcher.fetch_and_cache(@test_url)
      assert result.keys == [@test_key]
      assert result.ttl_seconds == 123
      assert is_struct(result.fetched_at, DateTime)
      assert is_struct(result.expires_at, DateTime)

      assert DateTime.diff(result.expires_at, result.fetched_at, :second) in 123..124
      assert {:ok, %{keys: [@test_key]}} = KeysetCache.get_keyset(@test_url)
    end

    test "rejects non-https urls before issuing a request" do
      assert {:error, :insecure_url_scheme} =
               KeysetFetcher.fetch_and_cache("http://example.com/jwks")
    end

    test "returns an error for invalid JSON payloads" do
      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "{invalid json",
           headers: []
         }}
      end)

      assert {:error, :json_decode_failed} = KeysetFetcher.fetch_and_cache(@test_url)
      assert {:error, :not_found} = KeysetCache.get_keyset(@test_url)
    end

    test "returns an error for invalid JWKS payloads" do
      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"unexpected" => []}),
           headers: []
         }}
      end)

      assert {:error, :invalid_jwks_format} = KeysetFetcher.fetch_and_cache(@test_url)
      assert {:error, :not_found} = KeysetCache.get_keyset(@test_url)
    end

    test "returns http errors without caching partial results" do
      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 503, body: "", headers: []}}
      end)

      assert {:error, {:http_error, 503}} = KeysetFetcher.fetch_and_cache(@test_url)
      assert {:error, :not_found} = KeysetCache.get_keyset(@test_url)
    end
  end

  describe "parse_cache_control_max_age/1" do
    test "uses the default ttl when max-age is missing" do
      assert KeysetFetcher.parse_cache_control_max_age([{"cache-control", "public"}]) == 3600
      assert KeysetFetcher.parse_cache_control_max_age([]) == 3600
    end
  end
end
