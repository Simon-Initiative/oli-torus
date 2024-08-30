defmodule Oli.Activities.Query.ExecutorTest do
  use Oli.DataCase

  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Logic.Expression
  alias Oli.Activities.Realizer.Query.Builder
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Activities.Realizer.Query.Executor
  alias Oli.Activities.Realizer.Query.Result

  describe "resources" do
    setup do
      map = Seeder.base_project_with_resource2()

      Seeder.create_activity(
        %{
          scope: :banked,
          objectives: %{"1" => [1]},
          title: "1",
          content: %{model: %{stem: "this is the question"}}
        },
        map.publication,
        map.project,
        map.author
      )

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

      map
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
