defmodule Oli.Dashboard.Cache.PolicyTest do
  use ExUnit.Case, async: false

  alias Oli.Dashboard.Cache.Policy

  setup do
    previous = Application.get_env(:oli, Policy)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:oli, Policy)
        value -> Application.put_env(:oli, Policy, value)
      end
    end)

    :ok
  end

  describe "TTL policy readers" do
    test "returns documented default TTL values" do
      Application.delete_env(:oli, Policy)

      assert Policy.inprocess_ttl_minutes() == 15
      assert Policy.revisit_ttl_minutes() == 5
      assert Policy.inprocess_ttl_ms() == :timer.minutes(15)
      assert Policy.revisit_ttl_ms() == :timer.minutes(5)
    end

    test "honors application config overrides" do
      Application.put_env(:oli, Policy, %{
        inprocess_ttl_minutes: 30,
        revisit_ttl_minutes: 10
      })

      assert Policy.inprocess_ttl_minutes() == 30
      assert Policy.revisit_ttl_minutes() == 10
      assert Policy.inprocess_ttl_ms() == :timer.minutes(30)
      assert Policy.revisit_ttl_ms() == :timer.minutes(10)
    end
  end

  describe "enrollment-tiered container caps" do
    test "calculates tier and cap deterministically across boundaries" do
      Application.put_env(:oli, Policy, %{
        small_enrollment_threshold: 20,
        normal_enrollment_threshold: 200,
        small_max_containers: 5,
        normal_max_containers: 12,
        large_max_containers: 20
      })

      assert Policy.tier_for_enrollment(0) == :small
      assert Policy.tier_for_enrollment(20) == :small
      assert Policy.tier_for_enrollment(21) == :normal
      assert Policy.tier_for_enrollment(200) == :normal
      assert Policy.tier_for_enrollment(201) == :large

      assert Policy.container_cap_for_enrollment(0) == 5
      assert Policy.container_cap_for_enrollment(200) == 12
      assert Policy.container_cap_for_enrollment(5000) == 20
    end

    test "normalizes threshold ordering when misconfigured" do
      Application.put_env(:oli, Policy, %{
        small_enrollment_threshold: 400,
        normal_enrollment_threshold: 100
      })

      snapshot = Policy.snapshot()

      assert snapshot.small_enrollment_threshold == 100
      assert snapshot.normal_enrollment_threshold == 400
    end
  end
end
