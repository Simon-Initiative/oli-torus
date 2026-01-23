defmodule Oli.GenAI.HackneyPoolTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.HackneyPool

  describe "pool_name/0" do
    test "returns the expected pool name" do
      assert HackneyPool.pool_name() == :genai_pool
    end
  end

  describe "pool_size/0" do
    test "returns the configured pool size from application env" do
      # The default configured value should be 100
      assert HackneyPool.pool_size() == 100
    end
  end

  describe "pool initialization" do
    test "pool is started and accessible after application boot" do
      # The pool should be running since it's started by the application supervisor
      pool_name = HackneyPool.pool_name()

      # Verify we can get pool stats (which confirms the pool exists)
      stats = :hackney_pool.get_stats(pool_name)
      assert is_list(stats)
    end
  end
end
