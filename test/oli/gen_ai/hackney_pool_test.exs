defmodule Oli.GenAI.HackneyPoolTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.HackneyPool
  alias Oli.GenAI.Completions.RegisteredModel

  describe "pool_name/0" do
    test "returns the expected pool name" do
      assert HackneyPool.pool_name() == :genai_slow_pool
      assert HackneyPool.pool_name(:slow) == :genai_slow_pool
      assert HackneyPool.pool_name(:fast) == :genai_fast_pool
      assert HackneyPool.pool_name(%RegisteredModel{pool_class: :fast}) == :genai_fast_pool
    end
  end

  describe "pool_size/0" do
    test "returns the configured pool sizes from application env" do
      # The default configured value should be 100 for both pools
      assert HackneyPool.pool_size() == 100
      assert HackneyPool.pool_size(:slow) == 100
      assert HackneyPool.pool_size(:fast) == 100
    end
  end

  describe "pool initialization" do
    test "pool is started and accessible after application boot" do
      # The pool should be running since it's started by the application supervisor
      slow_pool = HackneyPool.pool_name(:slow)
      fast_pool = HackneyPool.pool_name(:fast)

      # Verify we can get pool stats (which confirms the pool exists)
      assert is_list(:hackney_pool.get_stats(slow_pool))
      assert is_list(:hackney_pool.get_stats(fast_pool))
    end
  end
end
