defmodule Oli.Delivery.Sections.SectionCacheTest do
  use ExUnit.Case, async: false

  alias Oli.Delivery.Sections.SectionCache

  test "put/2 stores a value in the cache and get/1 retrieves the value" do
    assert :ok == SectionCache.put(:test_key, "test_value")
    {:ok, value} = SectionCache.get(:test_key)
    assert "test_value" == value
  end

  test "delete/1 removes a value from the cache" do
    SectionCache.put(:test_key, "test_value")
    assert :ok == SectionCache.delete(:test_key)
    {:ok, value} = SectionCache.get(:test_key)
    assert value == nil
  end

  @tag :flaky
  test "get_or_compute/3 calculates and stores the value if it is not present" do
    Phoenix.PubSub.subscribe(Oli.PubSub, SectionCache.cache_topic())
    slug = "test_slug"
    cache_id = "#{slug}_full_hierarchy"
    hierarchy = %{example: "hierarchy"}

    ## 1st call that stores the value in the cache
    assert hierarchy ==
             SectionCache.get_or_compute(slug, :full_hierarchy, fn -> hierarchy end)

    # Check that the value was stored in the cache
    assert {:ok, hierarchy} == SectionCache.get(cache_id)

    # Check that a message was broadcasted with the new hierarchy
    assert_receive {:put, ^cache_id, ^hierarchy}

    ## 2nd call that fetches the value from the cache and does not store it
    assert hierarchy ==
             SectionCache.get_or_compute(slug, :full_hierarchy, fn -> hierarchy end)

    # Check that a message was not broadcasted this time
    refute_receive {:put, ^cache_id, ^hierarchy}
  end

  test "clear/1 deletes all stored values for the given section in the cache" do
    Phoenix.PubSub.subscribe(Oli.PubSub, SectionCache.cache_topic())
    slug = "another_test_slug"

    cache_ids =
      SectionCache.cache_keys()
      |> Enum.map(&"#{slug}_#{&1}")

    for key <- cache_ids, do: SectionCache.put(key, "dummy_value")

    SectionCache.clear(slug)

    # All values should have been deleted from the cache
    for key <- cache_ids, do: assert({:ok, nil} == SectionCache.get(key))

    # Check that a message was broadcasted for each broadcastable key
    for key <- SectionCache.broadcastable_cache_keys() do
      cache_id = "#{slug}_#{key}"
      assert_receive({:delete, ^cache_id})
    end
  end

  test "clear/2 deletes the stored values for the given section keys in the cache" do
    Phoenix.PubSub.subscribe(Oli.PubSub, SectionCache.cache_topic())
    slug = "third_test_slug"

    cache_ids =
      SectionCache.cache_keys()
      |> Enum.map(&"#{slug}_#{&1}")

    for key <- cache_ids, do: SectionCache.put(key, "dummy_value")

    SectionCache.clear(slug, [:ordered_container_labels])

    # Only the specified key should have been deleted from the cache
    for key <- cache_ids do
      if key != "third_test_slug_ordered_container_labels" do
        assert({:ok, "dummy_value"} == SectionCache.get(key))
      else
        assert({:ok, nil} == SectionCache.get("third_test_slug_ordered_container_labels"))
      end
    end

    assert_receive({:delete, "third_test_slug_ordered_container_labels"})
  end

  test "clear/2 returns an error when a non-existing key is provided" do
    assert {:error, :not_existing_cache_key} =
             SectionCache.clear("some_section_slug", [:invented_key])
  end
end
