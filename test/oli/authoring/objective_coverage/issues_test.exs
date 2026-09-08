defmodule Oli.Authoring.ObjectiveCoverage.IssuesTest do
  use ExUnit.Case, async: true

  alias Oli.Authoring.ObjectiveCoverage.Issues

  describe "default_thresholds/0" do
    test "returns the recommended formative and summative thresholds" do
      assert Issues.default_thresholds() == %{formative: 3, summative: 3}
    end
  end

  describe "classify/2" do
    test "flags a formative shortfall" do
      assert %{formative_issue: true, summative_issue: false, any_issue: true} =
               Issues.classify(%{formative_activity_count: 2, summative_activity_count: 3})
    end

    test "flags a summative shortfall" do
      assert %{formative_issue: false, summative_issue: true, any_issue: true} =
               Issues.classify(%{formative_activity_count: 3, summative_activity_count: 2})
    end

    test "flags both a formative and a summative shortfall" do
      assert %{formative_issue: true, summative_issue: true, any_issue: true} =
               Issues.classify(%{formative_activity_count: 2, summative_activity_count: 2})
    end

    test "reports no issue when both counts meet the threshold" do
      assert %{formative_issue: false, summative_issue: false, any_issue: false} =
               Issues.classify(%{formative_activity_count: 3, summative_activity_count: 3})
    end

    test "uses supplied project thresholds" do
      assert %{formative_issue: false, summative_issue: false, any_issue: false} =
               Issues.classify(
                 %{formative_activity_count: 1, summative_activity_count: 2},
                 %{formative: 1, summative: 2}
               )
    end
  end

  describe "classify_all/2" do
    test "propagates child issues to every ancestor while retaining direct child reasons" do
      model = %{
        objectives_by_id: %{1 => %{}, 2 => %{}, 3 => %{}},
        parents_by_child: %{2 => [1], 3 => [2]},
        coverage_by_objective: %{
          1 => %{formative_activity_count: 3, summative_activity_count: 3},
          2 => %{formative_activity_count: 3, summative_activity_count: 3},
          3 => %{formative_activity_count: 2, summative_activity_count: 3}
        }
      }

      issues = Issues.classify_all(model)

      assert %{
               formative_issue: true,
               summative_issue: false,
               any_issue: true,
               direct_formative_issue: false
             } =
               issues[1]

      assert %{
               formative_issue: true,
               summative_issue: false,
               any_issue: true,
               direct_formative_issue: false
             } =
               issues[2]

      assert %{
               formative_issue: true,
               summative_issue: false,
               any_issue: true,
               direct_formative_issue: true
             } =
               issues[3]
    end

    test "terminates when malformed hierarchy data contains a cycle" do
      model = %{
        objectives_by_id: %{1 => %{}, 2 => %{}},
        parents_by_child: %{1 => [2], 2 => [1]},
        coverage_by_objective: %{
          1 => %{formative_activity_count: 3, summative_activity_count: 3},
          2 => %{formative_activity_count: 3, summative_activity_count: 2}
        }
      }

      assert %{1 => %{summative_issue: true}, 2 => %{summative_issue: true}} =
               Issues.classify_all(model)
    end

    test "propagates an issue to every parent when a child has more than one" do
      # 4 is shared by two otherwise-unrelated top-level objectives, 1 and 2.
      model = %{
        objectives_by_id: %{1 => %{}, 2 => %{}, 4 => %{}},
        parents_by_child: %{4 => [1, 2]},
        coverage_by_objective: %{
          1 => %{formative_activity_count: 3, summative_activity_count: 3},
          2 => %{formative_activity_count: 3, summative_activity_count: 3},
          4 => %{formative_activity_count: 2, summative_activity_count: 3}
        }
      }

      issues = Issues.classify_all(model)

      assert %{formative_issue: true, direct_formative_issue: false} = issues[1]
      assert %{formative_issue: true, direct_formative_issue: false} = issues[2]
      assert %{formative_issue: true, direct_formative_issue: true} = issues[4]
    end

    test "raises when an objective is missing from coverage_by_objective" do
      model = %{
        objectives_by_id: %{1 => %{}, 2 => %{}},
        parents_by_child: %{2 => [1]},
        coverage_by_objective: %{
          1 => %{formative_activity_count: 3, summative_activity_count: 3}
        }
      }

      assert_raise KeyError, fn -> Issues.classify_all(model) end
    end
  end

  describe "top-level issue ids" do
    test "includes a top-level objective flagged directly and one flagged only through a descendant" do
      model = %{
        objectives_by_id: %{1 => %{}, 2 => %{}, 3 => %{}},
        parents_by_child: %{3 => [2]},
        top_level_objective_ids: [1, 2],
        coverage_by_objective: %{
          1 => %{formative_activity_count: 2, summative_activity_count: 3},
          2 => %{formative_activity_count: 3, summative_activity_count: 3},
          3 => %{formative_activity_count: 2, summative_activity_count: 3}
        }
      }

      assert Issues.flagged_top_level_ids(model) == MapSet.new([1, 2])

      issues = Issues.classify_all(model)

      assert Issues.flagged_top_level_ids_from_issues(model, issues) == MapSet.new([1, 2])
    end

    test "excludes healthy top-level objectives even when other objectives in the snapshot are flagged" do
      model = %{
        objectives_by_id: %{1 => %{}, 2 => %{}},
        parents_by_child: %{},
        top_level_objective_ids: [1],
        coverage_by_objective: %{
          1 => %{formative_activity_count: 3, summative_activity_count: 3},
          2 => %{formative_activity_count: 0, summative_activity_count: 0}
        }
      }

      assert Issues.flagged_top_level_ids(model) == MapSet.new()
    end

    test "returns an empty set when no top-level objectives are flagged" do
      model = %{
        objectives_by_id: %{1 => %{}},
        parents_by_child: %{},
        top_level_objective_ids: [1],
        coverage_by_objective: %{
          1 => %{formative_activity_count: 3, summative_activity_count: 3}
        }
      }

      assert Issues.flagged_top_level_ids(model) == MapSet.new()
    end

    test "uses supplied project thresholds" do
      model = %{
        objectives_by_id: %{1 => %{}},
        parents_by_child: %{},
        top_level_objective_ids: [1],
        coverage_by_objective: %{
          1 => %{formative_activity_count: 1, summative_activity_count: 2}
        }
      }

      assert Issues.flagged_top_level_ids(model, %{formative: 1, summative: 2}) == MapSet.new()
    end
  end
end
