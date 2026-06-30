defmodule Oli.Activities.Query.ExecutorTest do
  use Oli.DataCase

  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Logic.Clause
  alias Oli.Activities.Realizer.Logic.Expression
  alias Oli.Activities.Realizer.Query.Batch
  alias Oli.Activities.Realizer.Query.Builder
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Activities.Realizer.Query.Executor
  alias Oli.Activities.Realizer.Query.Result

  describe "resources" do
    setup do
      map = Seeder.base_project_with_resource2()

      first_banked_activity =
        Seeder.create_activity(
          %{
            scope: :banked,
            objectives: %{"1" => [1]},
            title: "1",
            content: %{model: %{stem: "alpha question"}}
          },
          map.publication,
          map.project,
          map.author
        )

      second_banked_activity =
        Seeder.create_activity(
          %{
            scope: :banked,
            objectives: %{"1" => [1, 2]},
            title: "2",
            content: %{model: %{stem: "and another"}}
          },
          map.publication,
          map.project,
          map.author
        )

      Seeder.create_activity(
        %{
          scope: :embedded,
          objectives: %{"1" => [1, 2]},
          title: "2",
          content: %{model: %{stem: "and another"}}
        },
        map.publication,
        map.project,
        map.author
      )

      Map.merge(map, %{
        first_banked_activity: first_banked_activity,
        second_banked_activity: second_banked_activity
      })
    end

    test "queries for selection via objectives", %{publication: publication} do
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: ""
      }

      paging = %Paging{limit: 1, offset: 0}
      logic = %Logic{conditions: %Expression{fact: :objectives, operator: :contains, value: [2]}}

      {:ok, %Result{rows: rows, rowCount: 1}} =
        Builder.build(logic, source, paging, :paged)
        |> Executor.execute()

      assert Map.get(hd(rows), :title) == "2"
    end

    test "queries for paging", %{publication: publication} do
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: ""
      }

      paging = %Paging{limit: 1, offset: 0}
      logic = %Logic{conditions: %Expression{fact: :objectives, operator: :contains, value: [1]}}

      {:ok, %Result{rowCount: 1, totalCount: 2}} =
        Builder.build(logic, source, paging, :paged)
        |> Executor.execute()
    end

    test "optionally restricts results to specific activity resources", %{
      publication: publication,
      first_banked_activity: first_banked_activity,
      second_banked_activity: second_banked_activity
    } do
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: "",
        activity_resource_ids: [second_banked_activity.resource.id]
      }

      paging = %Paging{limit: 1, offset: 0}
      logic = %Logic{conditions: %Expression{fact: :objectives, operator: :contains, value: [2]}}

      assert {:ok, %Result{rows: [revision], rowCount: 1, totalCount: 1}} =
               Builder.build(logic, source, paging, :paged)
               |> Executor.execute()

      assert revision.resource_id == second_banked_activity.resource.id
      refute revision.resource_id == first_banked_activity.resource.id

      source = %Source{source | activity_resource_ids: [first_banked_activity.resource.id]}

      assert {:ok, %Result{rows: [], rowCount: 0, totalCount: 0}} =
               Builder.build(logic, source, paging, :paged)
               |> Executor.execute()
    end

    test "returns no results when restricted to no activity resources", %{
      publication: publication
    } do
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: "",
        activity_resource_ids: []
      }

      paging = %Paging{limit: 1, offset: 0}
      logic = %Logic{conditions: nil}

      assert {:ok, %Result{rows: [], rowCount: 0, totalCount: 0}} =
               Builder.build(logic, source, paging, :paged)
               |> Executor.execute()
    end

    test "queries for exact objectives via lateral join", %{publication: publication} do
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: ""
      }

      paging = %Paging{limit: 1, offset: 0}
      logic = %Logic{conditions: %Expression{fact: :objectives, operator: :equals, value: [1]}}

      {:ok, %Result{rowCount: 1, totalCount: 1}} =
        Builder.build(logic, source, paging, :paged)
        |> Executor.execute()
    end

    test "queries for NOT exact objectives via lateral join", %{publication: publication} do
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: ""
      }

      paging = %Paging{limit: 2, offset: 0}

      logic = %Logic{
        conditions: %Expression{fact: :objectives, operator: :does_not_equal, value: [1]}
      }

      {:ok, %Result{rowCount: 1, totalCount: 1}} =
        Builder.build(logic, source, paging, :paged)
        |> Executor.execute()
    end

    test "queries for full text", %{publication: publication} do
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: ""
      }

      paging = %Paging{limit: 1, offset: 0}
      logic = %Logic{conditions: %Expression{fact: :text, operator: :contains, value: "question"}}

      {:ok, %Result{rowCount: 1, totalCount: 1}} =
        Builder.build(logic, source, paging, :paged)
        |> Executor.execute()
    end

    test "queries full text against activity titles", %{publication: publication} do
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: ""
      }

      paging = %Paging{limit: 1, offset: 0}
      logic = %Logic{conditions: %Expression{fact: :text, operator: :contains, value: "1"}}

      {:ok, %Result{rowCount: 1, totalCount: 1}} =
        Builder.build(logic, source, paging, :paged)
        |> Executor.execute()
    end

    test "queries for multiple full text expressions", %{publication: publication} do
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: ""
      }

      paging = %Paging{limit: 1, offset: 0}

      logic = %Logic{
        conditions: %Clause{
          operator: :all,
          children: [
            %Expression{fact: :text, operator: :contains, value: "alpha"},
            %Expression{fact: :text, operator: :contains, value: "question"}
          ]
        }
      }

      {:ok, %Result{rowCount: 1, totalCount: 1}} =
        Builder.build(logic, source, paging, :paged)
        |> Executor.execute()
    end

    test "batch executes paged queries keyed by query id", %{
      publication: publication,
      first_banked_activity: first_banked_activity,
      second_banked_activity: second_banked_activity
    } do
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: ""
      }

      paging = %Paging{limit: 2, offset: 0}

      first_logic = %Logic{
        conditions: %Expression{fact: :text, operator: :contains, value: "question"}
      }

      second_logic = %Logic{
        conditions: %Expression{fact: :text, operator: :contains, value: "another"}
      }

      assert {:ok,
              %{
                "first" => %Result{rows: [first_revision], rowCount: 1, totalCount: 1},
                "second" => %Result{rows: [second_revision], rowCount: 1, totalCount: 1}
              }} =
               Batch.execute(
                 [
                   {"first", first_logic, source},
                   {"second", second_logic, source}
                 ],
                 paging,
                 :paged
               )

      assert first_revision.resource_id == first_banked_activity.resource.id
      assert second_revision.resource_id == second_banked_activity.resource.id
    end

    test "batch preserves empty results for query ids", %{publication: publication} do
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: ""
      }

      paging = %Paging{limit: 1, offset: 0}

      matching_logic = %Logic{
        conditions: %Expression{fact: :objectives, operator: :contains, value: [1]}
      }

      empty_logic = %Logic{
        conditions: %Expression{fact: :objectives, operator: :contains, value: [999_999]}
      }

      assert {:ok,
              %{
                "matching" => %Result{rowCount: 1, totalCount: 2},
                "empty" => %Result{rows: [], rowCount: 0, totalCount: 0}
              }} =
               Batch.execute(
                 [
                   {"matching", matching_logic, source},
                   {"empty", empty_logic, source}
                 ],
                 paging,
                 :paged
               )
    end

    test "batch honors source exclusions per query", %{
      publication: publication,
      first_banked_activity: first_banked_activity,
      second_banked_activity: second_banked_activity
    } do
      paging = %Paging{limit: 2, offset: 0}
      logic = %Logic{conditions: %Expression{fact: :objectives, operator: :contains, value: [1]}}

      first_source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [second_banked_activity.resource.id],
        section_slug: ""
      }

      second_source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [first_banked_activity.resource.id],
        section_slug: ""
      }

      assert {:ok,
              %{
                "first-only" => %Result{rows: [first_revision], rowCount: 1, totalCount: 1},
                "second-only" => %Result{rows: [second_revision], rowCount: 1, totalCount: 1}
              }} =
               Batch.execute(
                 [
                   {"first-only", logic, first_source},
                   {"second-only", logic, second_source}
                 ],
                 paging,
                 :paged
               )

      assert first_revision.resource_id == first_banked_activity.resource.id
      assert second_revision.resource_id == second_banked_activity.resource.id
    end

    test "batch returns an empty map for no query specs" do
      assert {:ok, %{}} = Batch.execute([], %Paging{limit: 1, offset: 0}, :paged)
    end

    test "queries for activity type", %{publication: publication} do
      id = Oli.Activities.get_registration_by_slug("oli_multiple_choice").id

      # Verify the IN operator works
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: ""
      }

      paging = %Paging{limit: 1, offset: 0}

      logic = %Logic{
        conditions: %Expression{fact: :type, operator: :contains, value: [id]}
      }

      {:ok, %Result{rowCount: 1, totalCount: 2}} =
        Builder.build(logic, source, paging, :paged)
        |> Executor.execute()

      # Verify the exact match operator works, matching none
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: ""
      }

      paging = %Paging{limit: 1, offset: 0}

      logic = %Logic{
        conditions: %Expression{fact: :type, operator: :equals, value: id + 1}
      }

      {:ok, %Result{rowCount: 0}} =
        Builder.build(logic, source, paging, :paged)
        |> Executor.execute()
    end
  end
end
