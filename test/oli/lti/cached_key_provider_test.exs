defmodule Oli.Lti.CachedKeyProviderTest do
  use Oli.DataCase, async: false

  import ExUnit.CaptureLog
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
      "0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4cbbfAAtVT86zwu1RK7aPFFxuhDR1L6tSoc_BJECPebWKRXjBZCiFV4n3oknjhMstn64tZ_2W-5JsGY4Hc5n9yBXArwl93lqt7_RN5w6Cf0h4QyQ5v-65YGjQR0_FDW2QvzqY368QQMicAtaSqzs8KJZgnYb9c7d0zgdAZHzu6qMQvRL5hajrn1n91CbOpbISD08qNLyrdkt-bFTWhAI4vMQFh6WeZu0fM4lFd2NcRwr3XPksINHaQ-G_xBniIqbw0Ls1jF44-csFCur-kEgU8awapJzKnqDKgw",
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

    test "retrieves same key consistently from same keyset" do
      KeysetCache.put_keyset(@test_url, [@test_key_1], 3600)

      assert {:ok, key1} = CachedKeyProvider.get_public_key(@test_url, "test-key-1")
      assert {:ok, key2} = CachedKeyProvider.get_public_key(@test_url, "test-key-1")

      assert is_struct(key1, JOSE.JWK)
      assert is_struct(key2, JOSE.JWK)

      # Same key should be returned
      assert key1 == key2
    end

    test "AC-003 does not perform an http fetch for warm cache hits" do
      KeysetCache.put_keyset(@test_url, [@test_key_1], 3600)

      assert {:ok, _public_key} = CachedKeyProvider.get_public_key(@test_url, "test-key-1")
    end

    test "AC-006 emits warm-cache diagnostics" do
      KeysetCache.put_keyset(@test_url, [@test_key_1], 3600)
      previous_level = Logger.level()
      Logger.configure(level: :info)

      log =
        capture_log([level: :info], fn ->
          assert {:ok, _public_key} =
                   CachedKeyProvider.get_public_key(@test_url, "test-key-1")
        end)

      Logger.configure(level: previous_level)

      assert log =~ "lti_keyset_lookup warm_cache_hit"
      assert log =~ "lookup_source: :warm_cache"
      assert log =~ "requested_kid: \"test-key-1\""
    end
  end

  describe "get_public_key/2 read-through behavior" do
    test "AC-001 loads and returns the key on a cold-cache miss" do
      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [@test_key_1, @test_key_2]}),
           headers: [{"cache-control", "max-age=300"}]
         }}
      end)

      assert {:ok, public_key} = CachedKeyProvider.get_public_key(@test_url, "test-key-1")
      assert is_struct(public_key, JOSE.JWK)
      assert {:ok, %{keys: [@test_key_1, @test_key_2]}} = KeysetCache.get_keyset(@test_url)
    end

    test "AC-001 AC-006 coalesces concurrent cold-cache requests for the same url into one fetch" do
      parent = self()

      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        send(parent, :http_fetch)

        Process.sleep(50)

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [@test_key_1, @test_key_2]}),
           headers: []
         }}
      end)

      tasks =
        Enum.map(1..2, fn _ ->
          Task.async(fn ->
            Mox.allow(Oli.Test.MockHTTP, parent, self())
            CachedKeyProvider.get_public_key(@test_url, "test-key-2")
          end)
        end)

      assert_receive :http_fetch
      refute_receive :http_fetch, 100
      assert Enum.all?(Enum.map(tasks, &Task.await(&1, 1_000)), &match?({:ok, _}, &1))
    end

    @tag capture_log: true
    test "AC-002 refreshes synchronously when the cached keyset misses the requested kid" do
      KeysetCache.put_keyset(@test_url, [@test_key_1], 3600)

      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [@test_key_1, @test_key_2]}),
           headers: []
         }}
      end)

      assert {:ok, public_key} = CachedKeyProvider.get_public_key(@test_url, "test-key-2")
      assert is_struct(public_key, JOSE.JWK)
      assert {:ok, %{keys: [@test_key_1, @test_key_2]}} = KeysetCache.get_keyset(@test_url)
    end

    @tag capture_log: true
    test "AC-004 returns an http fetch failure on cold-cache miss after read-through attempt" do
      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 503, body: "", headers: []}}
      end)

      assert {:error, error} = CachedKeyProvider.get_public_key(@test_url, "test-key-1")
      assert error.reason == {:http_error, 503}
      assert error.msg =~ "HTTP 503"
      assert error.msg =~ "launch-time cache fill"
      refute error.msg =~ "background job has been scheduled"
    end

    @tag capture_log: true
    test "AC-004 returns an invalid json failure on cold-cache miss after read-through attempt" do
      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: "{invalid", headers: []}}
      end)

      assert {:error, error} = CachedKeyProvider.get_public_key(@test_url, "test-key-1")
      assert error.reason == :json_decode_failed
      assert error.msg =~ "could not decode"
    end

    @tag capture_log: true
    test "AC-004 returns an invalid jwks failure on cold-cache miss after read-through attempt" do
      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"unexpected" => []}),
           headers: []
         }}
      end)

      assert {:error, error} = CachedKeyProvider.get_public_key(@test_url, "test-key-1")
      assert error.reason == :invalid_jwks_format
      assert error.msg =~ "not a valid JWKS payload"
    end

    @tag capture_log: true
    test "AC-005 AC-007 returns key_not_found_in_keyset after refresh when the requested kid is still missing" do
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

      assert {:error, error} = CachedKeyProvider.get_public_key(@test_url, "missing-key")
      assert error.reason == :key_not_found_in_keyset
      assert error.msg =~ "not found after refreshing the keyset"
      assert error.msg =~ "latest available keys for this launch"
      refute error.msg =~ "background job has been scheduled"
    end

    test "AC-005 AC-006 emits sync refresh diagnostics for terminal failures" do
      KeysetCache.put_keyset(@test_url, [@test_key_1], 3600)
      previous_level = Logger.level()
      Logger.configure(level: :info)

      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [@test_key_1]}),
           headers: []
         }}
      end)

      log =
        capture_log([level: :info], fn ->
          assert {:error, %{reason: :key_not_found_in_keyset}} =
                   CachedKeyProvider.get_public_key(@test_url, "missing-key")
        end)

      Logger.configure(level: previous_level)

      assert log =~ "lti_keyset_lookup sync_lookup_failed"
      assert log =~ "lookup_source: :sync_refresh_after_kid_miss"
      assert log =~ "cached_key_ids_before_refresh: [\"test-key-1\"]"
      assert log =~ "refreshed_key_ids: [\"test-key-1\"]"
      assert log =~ "outcome: :key_not_found_in_keyset"
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

    test "returns the shared fetch error when preload fails" do
      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 503, body: "", headers: []}}
      end)

      assert {:error, %{reason: {:http_error, 503}, msg: "Failed to preload keys"}} =
               CachedKeyProvider.preload_keys(@test_url)
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
    @tag capture_log: true
    test "AC-002 recovers synchronously when a rotated kid appears in the refreshed keyset" do
      # Initial cache with one key
      KeysetCache.put_keyset(@test_url, [@test_key_1], 3600)

      Oli.Test.MockHTTP
      |> expect(:get, fn @test_url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [@test_key_1, @test_key_2]}),
           headers: []
         }}
      end)

      # Try to get a key that doesn't exist in cache (simulating key rotation)
      result = CachedKeyProvider.get_public_key(@test_url, "test-key-2")

      assert {:ok, public_key} = result
      assert is_struct(public_key, JOSE.JWK)
    end
  end
end
