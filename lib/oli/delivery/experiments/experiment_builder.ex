defmodule Oli.Delivery.Experiments.ExperimentBuilder do

  @doc """
  Builds the JSON representation of an Upgrade experiment, which (after downloaded) can be
  used to import the experiment into Upgrade.
  """
  def build(%Oli.Authoring.Course.Project{slug: slug, title: title}) do

    now = DateTime.utc_now() |> DateTime.to_string()
    {:ok, groups} = Oli.Resources.alternatives_groups(slug, Oli.Publishing.AuthoringResolver)

    %{
      "createdAt" => now,
      "updatedAt" => now,
      "versionNumber" => 1,
      "id" => UUID.uuid4(),
      "name" => title,
      "description" => "",
      "context" => [
        "add"
      ],
      "state" => "enrolling",
      "startOn" => nil,
      "consistencyRule" => "individual",
      "assignmentUnit" => "individual",
      "postExperimentRule" => "continue",
      "enrollmentCompleteCondition" => nil,
      "endOn" => nil,
      "revertTo" => nil,
      "tags" => [],
      "group" => nil,
      "logging" => true,
      "filterMode" => "excludeAll",
      "backendVersion" => "3.0.10",
      "type" => "Simple",
      "partitions" => do_partitions(groups, now),
      "conditions" => do_conditions(groups, now),
      "stateTimeLogs" => [
        %{
          "createdAt" => now,
          "updatedAt" => now,
          "versionNumber" => 1,
          "id" => UUID.uuid4(),
          "fromState" => "scheduled",
          "toState" => "enrolling",
          "timeLog" => now
        }
      ],
      "queries" => do_queries(groups, slug, now),
      "experimentSegmentInclusion" => do_segment_inclusion(slug, now),
      "experimentSegmentExclusion" => do_segment_exclusion(now),
      "conditionAliases" => []
    }
  end

  defp do_partitions(decision_points, now) do
    Enum.map(decision_points, fn dp ->
      %{
        "createdAt" => now,
        "updatedAt" => now,
        "versionNumber" => 1,
        "id" => UUID.uuid4(),
        "twoCharacterId" => "AA",
        "site" => dp.title,
        "target" => "add-id1",
        "description" => "",
        "order" => 1,
        "excludeIfReached" => false,
        "factors" => []
      }
    end)
  end

  defp do_queries(decision_points, _, now) do
    Enum.map(decision_points, fn _dp ->
      %{
        "createdAt" => now,
        "updatedAt" => now,
        "versionNumber" => 1,
        "id" => UUID.uuid4,
        "name" => "average correctness",
        "query" => %{
          "operationType" => "avg"
        },
        "repeatedMeasure" => "MEAN",
        "metric" => %{
          "createdAt" => now,
          "updatedAt" => now,
          "versionNumber" => 1,
          "key" => "mastery@__@activities@__@correctness",
          "type" => "continuous",
          "allowedData" => nil
        }
      }
    end)
  end

  defp do_conditions(decision_points, now) do

    options = Enum.at(decision_points, 0).options
    count = Enum.count(options)

    weights = case count do
      0 -> []
      1 -> [100]
      2 -> [50, 50]
      3 -> [33, 33, 34]
      4 -> [25, 25, 25, 25]
      5 -> [20, 20, 20, 20, 20]
      6 -> [16, 16, 17, 17, 17, 17]
      _ -> List.duplicate(div(100, count), count)
    end

    code = fn index ->
      [index + 65, index + 65] |> List.to_string()
    end

    Enum.zip(options, weights)
    |> Enum.with_index()
    |> Enum.map(fn {{o, weight}, index} ->
      %{
        "createdAt" => now,
        "updatedAt" => now,
        "versionNumber" => 1,
        "id" => UUID.uuid4(),
        "twoCharacterId" => code.(index),
        "name" => "",
        "description" => nil,
        "conditionCode" => o["name"],
        "assignmentWeight" => weight,
        "order" => index + 1,
        "conditionAliases" => [],
        "levelCombinationElements" => []
      }
    end)
  end

  defp do_segment_exclusion(now) do
    %{
      "createdAt" => now,
      "updatedAt" => now,
      "versionNumber" => 1,
      "segment" => %{
        "createdAt" => now,
        "updatedAt" => now,
        "versionNumber" => 1,
        "id" => UUID.uuid4,
        "name" => "Exclusion Segment",
        "description" => "Exclusion Segment",
        "context" => "add",
        "type" => "private",
        "individualForSegment" => [],
        "groupForSegment" => [],
        "subSegments" => []
      }
    }
  end

  defp do_segment_inclusion(slug, now) do
    %{
      "createdAt" => now,
      "updatedAt" => now,
      "versionNumber" => 1,
      "segment" => %{
        "createdAt" => now,
        "updatedAt" => now,
        "versionNumber" => 1,
        "id" => UUID.uuid4,
        "name" => "Inclusion Segment",
        "description" => "Inclusion Segment",
        "context" => "add",
        "type" => "private",
        "individualForSegment" => [],
        "groupForSegment" => [
          %{
            "createdAt" => now,
            "updatedAt" => now,
            "versionNumber" => 1,
            "groupId" => slug,
            "type" => "add-group1"
          }
        ],
        "subSegments" => []
      }
    }
  end

end
