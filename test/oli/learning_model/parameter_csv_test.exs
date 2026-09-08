defmodule Oli.LearningModel.ParameterCsvTest do
  use Oli.DataCase

  alias Oli.Accounts.SystemRole
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.LearningModel.ParameterCsv
  alias Oli.Publishing.{AuthoringResolver, PublishedResource}
  alias Oli.Resources.{ResourceType, Revision}

  @moduletag capture_log: true

  setup do
    seed = Seeder.base_project_with_resource2()
    admin = author_fixture(%{system_role_id: SystemRole.role_id().content_admin})

    {:ok, objective} =
      ResourceEditor.create(seed.project.slug, admin, ResourceType.id_for_objective(), %{
        title: "Objective, one"
      })

    {:ok, activity} =
      ResourceEditor.create(seed.project.slug, admin, ResourceType.id_for_activity(), %{
        title: "Activity",
        activity_type_id: Oli.Activities.get_registration_by_slug("oli_multiple_choice").id,
        content: %{"authoring" => %{"parts" => [%{"id" => "p1"}, %{"id" => "p2"}]}}
      })

    {:ok, Map.merge(seed, %{admin: admin, objective: objective, activity: activity})}
  end

  test "exports every working resource with default parameters and round trips without revisions",
       s do
    rows = export_rows(s)

    assert Enum.find(rows, &(&1["resource_id"] == to_string(s.objective.resource_id))) == %{
             "title" => "Objective, one",
             "resource_id" => to_string(s.objective.resource_id),
             "children_ids" => "[]",
             "beta_lo" => "0.0",
             "beta_difficulty" => ""
           }

    activity = Enum.find(rows, &(&1["resource_id"] == to_string(s.activity.resource_id)))
    assert Jason.decode!(activity["beta_difficulty"]) == %{"p1" => 0.0, "p2" => 0.0}
    count = Repo.aggregate(Revision, :count)
    assert {:ok, %{changed: 0, unchanged: 2}} = upload(s, rows)
    assert Repo.aggregate(Revision, :count) == count
    assert latest(s, s.objective).learning_model_parameters == nil
  end

  test "changes both types with tracked revisions, preserves original content, and reimport is a no-op",
       s do
    rows = trained_rows(s)
    assert {:ok, %{changed: 2, unchanged: 0}} = upload(s, rows)
    objective = latest(s, s.objective)
    activity = latest(s, s.activity)
    assert objective.previous_revision_id == s.objective.id
    assert activity.previous_revision_id == s.activity.id
    assert objective.author_id == s.admin.id
    assert objective.learning_model_parameters.payload.beta_lo == -1.25
    assert activity.learning_model_parameters.payload.parts["p1"].beta_difficulty == 2.5
    assert activity.content == s.activity.content
    assert Repo.get!(Revision, s.objective.id).learning_model_parameters == nil
    assert {:ok, %{changed: 0, unchanged: 2}} = upload(s, rows)
    assert latest(s, s.objective).id == objective.id
    assert export_rows(s) == rows
  end

  test "exports shared children once and quotes multiline and formula titles", s do
    {:ok, child} =
      ResourceEditor.create(s.project.slug, s.admin, ResourceType.id_for_objective(), %{
        title: "=SUM(1,2)"
      })

    for title <- ["Parent\nA", "Parent B"] do
      ResourceEditor.create(s.project.slug, s.admin, ResourceType.id_for_objective(), %{
        title: title,
        children: [child.resource_id]
      })
    end

    rows = export_rows(s)
    assert Enum.count(rows, &(&1["resource_id"] == to_string(child.resource_id))) == 1
    assert Enum.count(rows, &(&1["children_ids"] == Jason.encode!([child.resource_id]))) == 2
    assert Enum.any?(rows, &(&1["title"] == "'=SUM(1,2)"))
    assert Enum.any?(rows, &(&1["title"] == "Parent\nA"))
  end

  test "invalid later row rolls back earlier changes", s do
    [first, second] = trained_rows(s)
    rows = [first, Map.put(second, "beta_difficulty", ~s({"unknown": 4}))]
    assert {:error, message} = upload(s, rows)
    assert message =~ "Row 3"
    assert latest(s, s.objective).id == s.objective.id
    assert latest(s, s.activity).id == s.activity.id
  end

  test "rejects duplicates and resources from another project", s do
    [row | _] = trained_rows(s)
    assert {:error, _} = upload(s, [row, row])
    assert latest(s, s.objective).id == s.objective.id
    other = Seeder.base_project_with_resource2()
    assert {:error, _} = upload(%{s | project: other.project}, [row])
  end

  test "rejects malformed headers, empty files, invalid numbers and mismatched columns", s do
    for csv <- ["", "bad,headers\n", "title,resource_id,children_ids,beta_lo,beta_difficulty\n"] do
      assert {:error, _} = ParameterCsv.import(s.project, s.admin, [csv])
    end

    [row | _] = export_rows(s)

    for invalid <- ["NaN", "Infinity", "1e999", "1.2x", ""] do
      assert {:error, _} = upload(s, [Map.put(row, "beta_lo", invalid)])
    end

    assert {:error, _} = upload(s, [Map.put(row, "beta_difficulty", "{}")])
  end

  test "rejects nonnumeric activity values and missing part IDs", s do
    row = List.last(export_rows(s))

    for value <- [~s({"p1":"2","p2":0}), ~s({"p1":2}), "[]", "null", "broken"] do
      assert {:error, _} = upload(s, [Map.put(row, "beta_difficulty", value)])
    end
  end

  test "respects active authoring locks", s do
    Repo.update_all(from(pr in PublishedResource, where: pr.revision_id == ^s.objective.id),
      set: [
        locked_by_id: s.author.id,
        lock_updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      ]
    )

    assert {:error, message} = upload(s, trained_rows(s))
    assert message =~ "being edited"
    assert latest(s, s.objective).id == s.objective.id
  end

  test "ordinary project authors cannot export or import", s do
    assert {:error, _} = ParameterCsv.export(s.project, s.author, &Enum.to_list/1)
    assert {:error, _} = ParameterCsv.import(s.project, s.author, [])
  end

  test "includes activities without parts and excludes deleted resources", s do
    {:ok, empty} =
      ResourceEditor.create(s.project.slug, s.admin, ResourceType.id_for_activity(), %{
        title: "No parts",
        activity_type_id: s.activity.activity_type_id,
        content: %{}
      })

    ResourceEditor.delete(s.project.slug, s.objective.resource_id, s.admin)
    rows = export_rows(s)
    assert length(rows) == 2

    assert Enum.find(rows, &(&1["resource_id"] == to_string(empty.resource_id)))[
             "beta_difficulty"
           ] == "{}"

    assert {:ok, %{changed: 0, unchanged: 2}} = upload(s, rows)
  end

  test "adaptive export follows persisted parts including rule-scored and stateful parts", s do
    content = %{
      "partsLayout" => [],
      "authoring" => %{
        "parts" => [
          %{"id" => "scorable", "type" => "janus-mcq"},
          %{"id" => "stateful", "type" => "janus-video"},
          %{"id" => "rule", "type" => "custom-widget"},
          %{"id" => "ignored", "type" => "custom-widget"}
        ],
        "rules" => [%{"conditions" => %{"value" => "stage.rule.value"}}]
      }
    }

    {:ok, adaptive} =
      ResourceEditor.create(s.project.slug, s.admin, ResourceType.id_for_activity(), %{
        title: "Adaptive",
        activity_type_id: s.activity.activity_type_id,
        content: content
      })

    row = Enum.find(export_rows(s), &(&1["resource_id"] == to_string(adaptive.resource_id)))

    assert Jason.decode!(row["beta_difficulty"]) == %{
             "scorable" => 0.0,
             "stateful" => 0.0,
             "rule" => 0.0
           }

    values = %{"scorable" => 1.0, "stateful" => 2.0, "rule" => 3.0}

    assert {:ok, %{changed: 1}} =
             upload(s, [Map.put(row, "beta_difficulty", Jason.encode!(values))])
  end

  test "working edits leave published mappings and parameters untouched", s do
    {:ok, published} =
      Oli.Publishing.create_publication(%{
        project_id: s.project.id,
        root_resource_id: s.publication.root_resource_id,
        published: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    {:ok, mapping} =
      Oli.Publishing.create_published_resource(%{
        publication_id: published.id,
        resource_id: s.objective.resource_id,
        revision_id: s.objective.id
      })

    assert length(export_rows(s)) == 2
    assert {:ok, %{changed: 2}} = upload(s, trained_rows(s))
    assert Repo.get!(PublishedResource, mapping.id).revision_id == s.objective.id
    assert Repo.get!(Revision, s.objective.id).learning_model_parameters == nil
  end

  test "partial stored parameters export missing parts as defaults without a no-op revision", s do
    parameters = %{
      schema_version: 1,
      model: "lkt_aoa",
      model_version: 2,
      parameter_type: "activity",
      payload: %{parts: %{"p1" => %{beta_difficulty: 4.0}}}
    }

    {:ok, revision} =
      ResourceEditor.edit(s.project.slug, s.activity.resource_id, s.admin, %{
        learning_model_parameters: parameters
      })

    rows = export_rows(s)
    assert Jason.decode!(List.last(rows)["beta_difficulty"]) == %{"p1" => 4.0, "p2" => 0.0}
    assert {:ok, %{changed: 0}} = upload(s, rows)
    assert latest(s, s.activity).id == revision.id
  end

  test "streaming export crosses cursor batches without losing resources", s do
    for index <- 1..251 do
      {:ok, _} =
        ResourceEditor.create(s.project.slug, s.admin, ResourceType.id_for_objective(), %{
          title: "LO #{index}"
        })
    end

    rows = export_rows(s)
    assert length(rows) == 253
    assert length(Enum.uniq_by(rows, & &1["resource_id"])) == 253
  end

  for size <- [1, 249, 250, 251, 505, 2000] do
    @tag timeout: 120_000
    test "imports #{size} resources with queries proportional to batches", s do
      size = unquote(size)
      rows = rows_for_count(s, size)
      batches = div(size + 249, 250)

      {result, queries} = capture_queries(fn -> upload(s, rows) end)
      assert result == {:ok, %{changed: size, unchanged: 0}}
      assert length(queries) <= 5 * batches + 5
      assert Enum.count(queries, &String.starts_with?(&1, "INSERT INTO revisions")) == batches

      assert Enum.count(queries, &String.starts_with?(&1, "UPDATE published_resources")) ==
               batches

      # All mappings, including the final partial batch, must point at their new values.
      current = Map.new(export_rows(s), &{&1["resource_id"], &1})
      for row <- rows, do: assert(current[row["resource_id"]] == row)

      {result, queries} = capture_queries(fn -> upload(s, rows) end)
      assert result == {:ok, %{changed: 0, unchanged: size}}
      assert length(queries) <= 3 * batches + 5
      refute Enum.any?(queries, &String.starts_with?(&1, "INSERT INTO revisions"))
      refute Enum.any?(queries, &String.starts_with?(&1, "UPDATE published_resources"))
    end
  end

  test "a failure in the second batch rolls back revisions and mappings from the first", s do
    rows = rows_for_count(s, 251)
    original_rows = export_rows(s)
    count = Repo.aggregate(Revision, :count)
    invalid_rows = List.update_at(rows, 250, &Map.put(&1, "beta_difficulty", "invalid"))

    {result, queries} = capture_queries(fn -> upload(s, invalid_rows) end)
    assert {:error, message} = result
    assert message =~ "Row 252"
    assert Enum.count(queries, &String.starts_with?(&1, "INSERT INTO revisions")) == 1
    assert Repo.aggregate(Revision, :count) == count
    assert export_rows(s) == original_rows
  end

  test "duplicate IDs across batches roll back the entire import", s do
    rows = rows_for_count(s, 250)
    count = Repo.aggregate(Revision, :count)
    assert {:error, message} = upload(s, rows ++ [hd(rows)])
    assert message =~ "Row 252"
    assert message =~ "duplicate"
    assert Repo.aggregate(Revision, :count) == count
    assert latest(s, s.objective).id == s.objective.id
  end

  test "bulk copy preserves every other persisted field, including content and embeds", s do
    {:ok, previous} =
      ResourceEditor.edit(s.project.slug, s.activity.resource_id, s.admin, %{
        content:
          Map.put(s.activity.content, "large_content", String.duplicate("content", 10_000)),
        objectives: %{"p1" => [s.objective.resource_id]},
        tags: [s.objective.resource_id],
        intro_content: %{"text" => "Introduction"},
        graded: true,
        ai_enabled: true,
        scope: :banked,
        max_attempts: 7,
        time_limit: 50,
        duration_minutes: 9,
        legacy: %{path: "legacy/path", id: "original"},
        explanation_strategy: %{type: :after_set_num_attempts, set_num_attempts: 3},
        collab_space_config: %{
          status: :enabled,
          participation_min_replies: 2,
          participation_min_posts: 1
        }
      })

    assert {:ok, %{changed: 2}} = upload(s, trained_rows(s))
    successor = latest(s, previous)

    copied_fields =
      Revision.__schema__(:fields) --
        [
          :id,
          :previous_revision_id,
          :author_id,
          :learning_model_parameters,
          :inserted_at,
          :updated_at
        ]

    assert Map.take(successor, copied_fields) == Map.take(previous, copied_fields)
    assert successor.previous_revision_id == previous.id
    assert successor.author_id == s.admin.id
    assert successor.inserted_at != nil
    assert successor.updated_at == successor.inserted_at
    assert successor.learning_model_parameters.payload.parts["p1"].beta_difficulty == 2.5
  end

  defp rows_for_count(s, size) do
    for index <- Enum.take(Stream.iterate(1, &(&1 + 1)), max(size - 2, 0)) do
      {:ok, _} =
        ResourceEditor.create(s.project.slug, s.admin, ResourceType.id_for_activity(), %{
          title: "Batch activity #{index}",
          activity_type_id: s.activity.activity_type_id,
          content: s.activity.content
        })
    end

    Enum.take(trained_rows(s), size)
  end

  defp capture_queries(fun) do
    handler = {__MODULE__, make_ref()}
    parent = self()

    :ok =
      :telemetry.attach(
        handler,
        [:oli, :repo, :query],
        fn _, _, metadata, _ ->
          case self() == parent do
            true -> send(parent, {handler, metadata.query})
            false -> :ok
          end
        end,
        nil
      )

    try do
      result = fun.()
      {result, collect_queries(handler, [])}
    after
      :telemetry.detach(handler)
    end
  end

  defp collect_queries(handler, acc) do
    receive do
      {^handler, query} -> collect_queries(handler, [query | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp export_rows(s) do
    {:ok, lines} = ParameterCsv.export(s.project, s.admin, &Enum.to_list/1)
    CSV.decode!(lines, headers: true) |> Enum.to_list()
  end

  defp trained_rows(s) do
    export_rows(s)
    |> Enum.map(fn row ->
      case row["beta_lo"] do
        "" -> Map.put(row, "beta_difficulty", Jason.encode!(%{"p1" => 2.5, "p2" => -0.5}))
        _ -> Map.put(row, "beta_lo", "-1.25")
      end
    end)
  end

  defp upload(s, rows),
    do:
      ParameterCsv.import(
        s.project,
        s.admin,
        CSV.encode(rows,
          headers: ["title", "resource_id", "children_ids", "beta_lo", "beta_difficulty"]
        )
      )

  defp latest(s, revision),
    do: AuthoringResolver.from_resource_id(s.project.slug, revision.resource_id)
end
