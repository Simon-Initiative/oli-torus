defmodule Oli.LearningModel.LktAoa.PerformanceTest do
  use Oli.DataCase

  alias Oli.LearningModel
  alias Oli.LearningModel.LktAoaFixtures

  @large_batch_size 500
  @operational_tables [
    "learning_model_attempt_applications",
    "published_resources",
    "learning_states",
    "prior_activity_part_evidence"
  ]

  @tag timeout: 120_000
  test "operational query count is stable for one and 500 GUID batches" do
    %{section: single_section, group: single_group} = LktAoaFixtures.lkt_fixture()

    single_count =
      operational_query_count(fn ->
        assert {:ok, %{status: :applied}} =
                 LearningModel.apply_evaluated_attempts(single_section, single_group)
      end)

    %{section: large_section, group: large_group} = large_fixture()

    large_count =
      operational_query_count(fn ->
        assert {:ok,
                %{
                  status: :applied,
                  input_attempt_count: @large_batch_size,
                  claimed_attempt_count: @large_batch_size
                }} = LearningModel.apply_evaluated_attempts(large_section, large_group)
      end)

    assert single_count == large_count
    assert large_count <= 6
  end

  @tag timeout: 120_000
  test "all-duplicate retries short-circuit after the claim statement" do
    %{section: section, group: group} = large_fixture()

    assert {:ok, %{status: :applied}} = LearningModel.apply_evaluated_attempts(section, group)

    retry_count =
      operational_query_count(fn ->
        assert {:ok,
                %{
                  status: :noop,
                  input_attempt_count: @large_batch_size,
                  claimed_attempt_count: 0,
                  contribution_count: 0
                }} = LearningModel.apply_evaluated_attempts(section, group)
      end)

    assert retry_count == 1
  end

  defp large_fixture do
    objective_count = 10

    LktAoaFixtures.lkt_fixture(%{
      objectives: Enum.map(1..objective_count, fn _ -> %{} end),
      part_attempts:
        Enum.map(1..@large_batch_size, fn index ->
          %{
            part_id: "part-#{index}",
            objective_indexes: [rem(index, objective_count), rem(index + 1, objective_count)],
            response: %{"input" => "response-#{index}"},
            score: if(rem(index, 2) == 0, do: 1.0, else: 0.0)
          }
        end)
    })
  end

  defp operational_query_count(fun) do
    handler_id = "lkt-aoa-performance-query-count-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach(
        handler_id,
        [:oli, :repo, :query],
        fn _event, _measurements, metadata, _config ->
          query = metadata.query || ""

          if Enum.any?(@operational_tables, &String.contains?(query, &1)) do
            send(parent, :operational_repo_query)
          end
        end,
        nil
      )

    try do
      fun.()
    after
      :telemetry.detach(handler_id)
    end

    collect_operational_queries(0)
  end

  defp collect_operational_queries(count) do
    receive do
      :operational_repo_query -> collect_operational_queries(count + 1)
    after
      0 -> count
    end
  end
end
