defmodule Oli.Dashboard.Cache.KeyTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Cache.Key
  alias Oli.Dashboard.OracleContext

  describe "inprocess/4 and parse/1" do
    test "builds canonical in-process key with deterministic fields" do
      {:ok, context} =
        OracleContext.new(%{
          dashboard_context_type: :section,
          dashboard_context_id: 901,
          user_id: 42
        })

      assert {:ok, cache_key} =
               Key.inprocess(
                 context,
                 %{container_type: :container, container_id: 3001},
                 :progress,
                 %{oracle_version: 2, data_version: "v2026-02-17"}
               )

      assert cache_key ==
               {:dashboard_oracle, :progress, 901, :container, 3001, 2, "v2026-02-17"}

      assert {:ok, parsed} = Key.parse(cache_key)
      assert parsed.key_type == :inprocess
      assert parsed.dashboard_context_id == 901
      assert parsed.container_type == :container
      assert parsed.container_id == 3001
      assert parsed.oracle_key == :progress
      assert parsed.oracle_version == 2
      assert parsed.data_version == "v2026-02-17"
    end

    test "rejects invalid container identity combinations" do
      assert {:error, {:invalid_cache_key, {:invalid_container, _}}} =
               Key.parse({:dashboard_oracle, :progress, 10, :course, 99, 1, "v1"})
    end
  end

  describe "revisit/5 and parse/1" do
    test "builds canonical revisit key with user-scoped identity" do
      context = %{dashboard_context_id: 1234}

      assert {:ok, cache_key} =
               Key.revisit(
                 77,
                 context,
                 %{container_type: :course, container_id: nil},
                 "student_support",
                 oracle_version: "o1",
                 data_version: 4
               )

      assert cache_key ==
               {:dashboard_revisit_oracle, 77, 1234, :course, nil, "student_support", "o1", 4}

      assert {:ok, parsed} = Key.parse(cache_key)
      assert parsed.key_type == :revisit
      assert parsed.user_id == 77
      assert parsed.container_type == :course
      assert parsed.container_id == nil
      assert parsed.oracle_key == "student_support"
    end
  end

  describe "matches_identity?/2" do
    test "returns true for exact identity match" do
      key =
        {:dashboard_oracle, :assessments, 12, :container, 22, "oracle-v1", "data-v2"}

      assert Key.matches_identity?(key, %{
               key_type: :inprocess,
               dashboard_context_id: 12,
               container_type: :container,
               container_id: 22,
               oracle_key: :assessments,
               oracle_version: "oracle-v1",
               data_version: "data-v2"
             })
    end

    test "returns false when revisit user id differs" do
      key =
        {:dashboard_revisit_oracle, 11, 12, :container, 22, :assessments, "oracle-v1", "data-v2"}

      refute Key.matches_identity?(key, %{
               key_type: :revisit,
               user_id: 999,
               dashboard_context_id: 12,
               container_type: :container,
               container_id: 22,
               oracle_key: :assessments,
               oracle_version: "oracle-v1",
               data_version: "data-v2"
             })
    end

    test "returns false for malformed identity maps" do
      key =
        {:dashboard_oracle, :progress, 7, :container, 8, 1, 2}

      refute Key.matches_identity?(key, %{container_type: :container})
    end
  end
end
