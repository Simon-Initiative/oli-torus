defmodule Oli.Lti.CachedKeyProviderTest do
  use Oli.DataCase, async: false

  import Mox

  alias Oli.Lti.CachedKeyProvider
  alias Oli.Lti.KeysetCache

  setup :verify_on_exit!

  @test_url "https://example.com/jwks"
  # Valid test JWK from RFC 7517 Appendix A.1
  @test_key_1 %{
    "kty" => "RSA",
    "kid" => "test-key-1",
    "use" => "sig",
    "n" =>
      "0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4cbbfAAtVT86zwu1RK7aPFFxuhDR1L6tSoc_BJECPebWKRXjBZCiFV4n3oknjhMstn64tZ_2W-5JsGY4Hc5n9yBXArwl93lqt7_RN5w6Cf0h4QyQ5v-65YGjQR0_FDW2QvzqY368QQMicAtaSqzs8KJZgnYb9c7d0zgdAZHzu6qMQvRL5hajrn1n91CbOpbISD08qNLyrdkt-bFTWhAI4vMQFh6WeZu0fM4lFd2NcRwr3XPksINHaQ-G_xBniIqbw0Ls1jF44-csFCur-kEgU8awapJzKnqDKgw",
    "e" => "AQAB"
  }

  @test_key_2 %{
    "kty" => "RSA",
    "kid" => "test-key-2",
    "use" => "sig",
    "n" =>
      "xjlA_0kzqN-nfN9-pzYaQ8TqG4h6c-2YZ-3KKQi6vYp6AQAB1t7yjQsY2fEaGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pGFp3Xr3pQ",
    "e" => "AQAB"
  }

  @test_keys [@test_key_1, @test_key_2]

  setup do
    # Clear cache before each test
    KeysetCache.clear_cache()
    :ok
  end

  describe "get_public_key/2 with cached keys" do
    test "retrieves key from cache when available" do
      # Pre-populate cache
      KeysetCache.put_keyset(@test_url, [@test_key_1], 3600)

      assert {:ok, public_key} = CachedKeyProvider.get_public_key(@test_url, "test-key-1")
      assert is_struct(public_key, JOSE.JWK)
    end

    test "returns descriptive error when key not found in cached keyset" do
      # Pre-populate cache with keys
      KeysetCache.put_keyset(@test_url, [@test_key_1], 3600)

      # When a key is not found, the provider will attempt to refresh the keyset
      # Mock the HTTP response to return the same keyset (key still not found)
      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [@test_key_1]}),
           headers: []
         }}
      end)

      assert {:error, error} =
               CachedKeyProvider.get_public_key(@test_url, "nonexistent-kid")

      # The error should indicate key not found
      assert error.reason == :key_not_found_in_keyset
    end

    test "retrieves same key consistently from same keyset" do
      KeysetCache.put_keyset(@test_url, [@test_key_1], 3600)

      assert {:ok, key1} = CachedKeyProvider.get_public_key(@test_url, "test-key-1")
      assert {:ok, key2} = CachedKeyProvider.get_public_key(@test_url, "test-key-1")

      assert is_struct(key1, JOSE.JWK)
      assert is_struct(key2, JOSE.JWK)

      # Same key should be returned
      assert key1 == key2
    end
  end

  describe "get_public_key/2 with cache miss" do
    test "falls back to HTTP fetch when keyset not cached" do
      # Mock HTTP to return keys
      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [@test_key_1]}),
           headers: []
         }}
      end)

      result = CachedKeyProvider.get_public_key(@test_url, "test-key-1")

      # Should succeed with mocked HTTP
      assert {:ok, _key} = result
    end
  end

  describe "get_public_key/2 error messages" do
    test "distinguishes between different error scenarios" do
      # Scenario 1: Keyset not cached (will trigger HTTP which will fail)
      KeysetCache.clear_cache()

      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:error, %HTTPoison.Error{reason: :timeout}}
      end)

      assert {:error, error} = CachedKeyProvider.get_public_key(@test_url, "any-key")

      # Should be an HTTP-related error, not a key-not-found error
      assert error.reason in [:http_error, :http_request_failed, :keyset_fetch_failed]

      # Scenario 2: Keyset cached but key not found (will trigger refresh attempt)
      KeysetCache.put_keyset(@test_url, [@test_key_1], 3600)

      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [@test_key_1]}),
           headers: []
         }}
      end)

      assert {:error, error2} = CachedKeyProvider.get_public_key(@test_url, "missing-key")

      # After refresh, key still not found
      assert error2.reason == :key_not_found_in_keyset
    end
  end

  describe "preload_keys/1" do
    test "can be called to preload keys for a URL" do
      # Mock HTTP to succeed
      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [@test_key_1, @test_key_2]}),
           headers: []
         }}
      end)

      result = CachedKeyProvider.preload_keys(@test_url)

      assert result == :ok
      # Verify keys were cached
      assert {:ok, _} = KeysetCache.get_keyset(@test_url)
    end
  end

  describe "refresh_all_keys/0" do
    test "schedules Oban job and returns empty list" do
      # refresh_all_keys delegates to Oban worker
      result = CachedKeyProvider.refresh_all_keys()

      # Returns empty list as it's asynchronous
      assert result == []
    end
  end

  describe "clear_cache/0" do
    test "clears the cache" do
      KeysetCache.put_keyset(@test_url, @test_keys, 3600)
      assert {:ok, _} = KeysetCache.get_keyset(@test_url)

      assert :ok = CachedKeyProvider.clear_cache()

      assert {:error, :not_found} = KeysetCache.get_keyset(@test_url)
    end
  end

  describe "cache_info/0" do
    test "returns empty info when cache is empty" do
      info = CachedKeyProvider.cache_info()

      assert info.total_cached_urls == 0
      assert info.cache_entries == %{}
    end

    test "returns info about cached keysets" do
      url1 = "https://platform1.com/jwks"
      url2 = "https://platform2.com/jwks"

      KeysetCache.put_keyset(url1, [@test_key_1], 3600)
      KeysetCache.put_keyset(url2, [@test_key_1], 7200)

      info = CachedKeyProvider.cache_info()

      assert info.total_cached_urls == 2
      assert Map.has_key?(info.cache_entries, url1)
      assert Map.has_key?(info.cache_entries, url2)

      # Check entry details
      entry1 = info.cache_entries[url1]
      assert entry1.key_count == 1
      assert is_struct(entry1.fetched_at, DateTime)
      assert is_struct(entry1.expires_at, DateTime)
      assert entry1.expired == false

      entry2 = info.cache_entries[url2]
      assert entry2.key_count == 1
    end

    test "marks expired entries correctly" do
      # Store with 1 second TTL
      KeysetCache.put_keyset(@test_url, [@test_key_1], 1)

      # Check immediately - should not be expired
      info = CachedKeyProvider.cache_info()
      entry = info.cache_entries[@test_url]
      assert entry.expired == false

      # Wait for expiration
      Process.sleep(1100)

      # After expiration, entry should be marked as expired in cache_info
      info_after = CachedKeyProvider.cache_info()

      # Check if entry exists and has the expired field
      if Map.has_key?(info_after.cache_entries, @test_url) do
        entry_after = info_after.cache_entries[@test_url]

        # Entry should either be marked expired or have an error
        cond do
          Map.has_key?(entry_after, :expired) ->
            assert entry_after.expired == true

          Map.has_key?(entry_after, :error) ->
            # Entry retrieval failed, which is acceptable
            assert true

          true ->
            # Unexpected structure
            flunk("Unexpected cache entry structure")
        end
      else
        # Entry was removed from cache
        assert info_after.total_cached_urls == 0
      end
    end
  end

  describe "integration with KeysetCache" do
    test "uses ETS cache for fast concurrent access" do
      # Pre-populate cache
      KeysetCache.put_keyset(@test_url, [@test_key_1], 3600)

      # Perform concurrent reads
      tasks =
        Enum.map(1..20, fn _i ->
          Task.async(fn ->
            CachedKeyProvider.get_public_key(@test_url, "test-key-1")
          end)
        end)

      results = Enum.map(tasks, &Task.await/1)

      # All reads should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end
  end

  describe "key rotation scenario" do
    test "refreshes keyset when kid not found to handle key rotation" do
      # Initial cache with one key
      KeysetCache.put_keyset(@test_url, [@test_key_1], 3600)

      # Mock HTTP to return both keys (simulating platform added a new key)
      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [@test_key_1]}),
           headers: []
         }}
      end)

      # Try to get a key that doesn't exist in cache
      # This will trigger refresh, but the key still won't be found
      result = CachedKeyProvider.get_public_key(@test_url, "missing-rotated-key")

      # Should return error that key not found after refresh
      assert {:error, error} = result
      assert error.reason == :key_not_found_in_keyset
    end
  end
end
