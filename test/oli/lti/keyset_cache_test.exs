defmodule Oli.Lti.KeysetCacheTest do
  use ExUnit.Case, async: false

  alias Oli.Lti.KeysetCache

  @test_url "https://example.com/jwks"
  @test_keys [
    %{
      "kty" => "RSA",
      "kid" => "key1",
      "use" => "sig",
      "n" => "test_n_value",
      "e" => "AQAB"
    },
    %{
      "kty" => "RSA",
      "kid" => "key2",
      "use" => "sig",
      "n" => "test_n_value_2",
      "e" => "AQAB"
    }
  ]

  setup do
    # Clear cache before each test
    KeysetCache.clear_cache()
    :ok
  end

  describe "put_keyset/3 and get_keyset/1" do
    test "stores and retrieves a keyset" do
      assert :ok = KeysetCache.put_keyset(@test_url, @test_keys, 3600)

      assert {:ok, keyset_data} = KeysetCache.get_keyset(@test_url)
      assert keyset_data.keys == @test_keys
      assert is_struct(keyset_data.fetched_at, DateTime)
      assert is_struct(keyset_data.expires_at, DateTime)
    end

    test "returns error for non-existent keyset" do
      assert {:error, :not_found} = KeysetCache.get_keyset("https://nonexistent.com/jwks")
    end

    test "respects TTL and expires keysets" do
      # Store with 1 second TTL
      assert :ok = KeysetCache.put_keyset(@test_url, @test_keys, 1)

      # Should be available immediately
      assert {:ok, _keyset_data} = KeysetCache.get_keyset(@test_url)

      # Wait for expiration
      Process.sleep(1100)

      # Should be expired and deleted
      assert {:error, :not_found} = KeysetCache.get_keyset(@test_url)
    end

    test "can store multiple keysets for different URLs" do
      url1 = "https://platform1.com/jwks"
      url2 = "https://platform2.com/jwks"

      keys1 = [%{"kid" => "platform1_key"}]
      keys2 = [%{"kid" => "platform2_key"}]

      KeysetCache.put_keyset(url1, keys1, 3600)
      KeysetCache.put_keyset(url2, keys2, 3600)

      assert {:ok, %{keys: ^keys1}} = KeysetCache.get_keyset(url1)
      assert {:ok, %{keys: ^keys2}} = KeysetCache.get_keyset(url2)
    end

    test "overwrites existing keyset when storing with same URL" do
      old_keys = [%{"kid" => "old_key"}]
      new_keys = [%{"kid" => "new_key"}]

      KeysetCache.put_keyset(@test_url, old_keys, 3600)
      assert {:ok, %{keys: ^old_keys}} = KeysetCache.get_keyset(@test_url)

      KeysetCache.put_keyset(@test_url, new_keys, 3600)
      assert {:ok, %{keys: ^new_keys}} = KeysetCache.get_keyset(@test_url)
    end
  end

  describe "get_public_key/2" do
    test "retrieves a specific key by kid from cached keyset" do
      KeysetCache.put_keyset(@test_url, @test_keys, 3600)

      assert {:ok, public_key} = KeysetCache.get_public_key(@test_url, "key1")
      assert is_struct(public_key, JOSE.JWK)
    end

    test "returns error when kid not found in keyset" do
      KeysetCache.put_keyset(@test_url, @test_keys, 3600)

      assert {:error, :key_not_found} =
               KeysetCache.get_public_key(@test_url, "nonexistent_kid")
    end

    test "returns error when keyset not cached" do
      assert {:error, :keyset_not_cached} =
               KeysetCache.get_public_key("https://uncached.com/jwks", "key1")
    end

    test "returns error when keyset is expired" do
      # Store with 1 second TTL
      KeysetCache.put_keyset(@test_url, @test_keys, 1)

      # Wait for expiration
      Process.sleep(1100)

      assert {:error, :keyset_not_cached} = KeysetCache.get_public_key(@test_url, "key1")
    end
  end

  describe "delete_keyset/1" do
    test "deletes a keyset from cache" do
      KeysetCache.put_keyset(@test_url, @test_keys, 3600)
      assert {:ok, _} = KeysetCache.get_keyset(@test_url)

      assert :ok = KeysetCache.delete_keyset(@test_url)
      assert {:error, :not_found} = KeysetCache.get_keyset(@test_url)
    end

    test "returns ok even when deleting non-existent keyset" do
      assert :ok = KeysetCache.delete_keyset("https://nonexistent.com/jwks")
    end
  end

  describe "list_cached_urls/0" do
    test "returns empty list when no keysets cached" do
      assert [] = KeysetCache.list_cached_urls()
    end

    test "returns list of all cached URLs" do
      url1 = "https://platform1.com/jwks"
      url2 = "https://platform2.com/jwks"

      KeysetCache.put_keyset(url1, @test_keys, 3600)
      KeysetCache.put_keyset(url2, @test_keys, 3600)

      cached_urls = KeysetCache.list_cached_urls()
      assert length(cached_urls) == 2
      assert url1 in cached_urls
      assert url2 in cached_urls
    end
  end

  describe "clear_cache/0" do
    test "clears all cached keysets" do
      url1 = "https://platform1.com/jwks"
      url2 = "https://platform2.com/jwks"

      KeysetCache.put_keyset(url1, @test_keys, 3600)
      KeysetCache.put_keyset(url2, @test_keys, 3600)

      assert length(KeysetCache.list_cached_urls()) == 2

      assert :ok = KeysetCache.clear_cache()
      assert [] = KeysetCache.list_cached_urls()
    end
  end

  describe "concurrent access" do
    test "handles concurrent reads and writes safely" do
      tasks =
        Enum.map(1..10, fn i ->
          Task.async(fn ->
            url = "https://platform#{i}.com/jwks"
            KeysetCache.put_keyset(url, @test_keys, 3600)
            KeysetCache.get_keyset(url)
          end)
        end)

      results = Enum.map(tasks, &Task.await/1)

      # All operations should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))
      assert length(KeysetCache.list_cached_urls()) == 10
    end
  end
end
