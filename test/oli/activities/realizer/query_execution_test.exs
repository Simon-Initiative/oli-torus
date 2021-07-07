defmodule Oli.Activities.QueryBuilderTest do
  use Oli.DataCase

  alias Oli.Activities.Realizer.QueryBuilder
  alias Oli.Activities.Realizer.Conditions
  alias Oli.Activities.Realizer.Conditions.Expression
  alias Oli.Activities.Realizer.Paging

  describe "resources" do
    setup do
      map = Seeder.base_project_with_resource2()

      Seeder.create_activity(
        %{
          objectives: %{"1" => [1]},
          title: "1",
          content: %{model: %{stem: "this is the question"}}
        },
        map.publication,
        map.project,
        map.author
      )

      Seeder.create_activity(
        %{objectives: %{"1" => [1, 2]}, title: "2", content: %{model: %{stem: "and another"}}},
        map.publication,
        map.project,
        map.author
      )

      map
    end

    test "queries for selection via objectives", %{publication: publication} do
      {sql, params} =
        %Conditions{conditions: %Expression{fact: :objectives, operator: :contains, value: [2]}}
        |> QueryBuilder.build_for_selection(publication.id, 1, [])

      %Postgrex.Result{rows: rows, columns: columns, num_rows: 1} =
        Ecto.Adapters.SQL.query!(Oli.Repo, sql, params)

      record = to_record(hd(rows), columns)
      assert Map.get(record, "title") == "2"
    end

    test "queries for paging", %{publication: publication} do
      {sql, params} =
        %Conditions{conditions: %Expression{fact: :objectives, operator: :contains, value: [1]}}
        |> QueryBuilder.build_for_paging(publication.id, %Paging{limit: 1, offset: 0})

      %Postgrex.Result{rows: rows, num_rows: 1, columns: columns} =
        Ecto.Adapters.SQL.query!(Oli.Repo, sql, params)

      record = to_record(hd(rows), columns)
      assert Map.get(record, "full_count") == 2
    end

    test "queries for exact objectives via lateral join", %{publication: publication} do
      {sql, params} =
        %Conditions{conditions: %Expression{fact: :objectives, operator: :equals, value: [1]}}
        |> QueryBuilder.build_for_paging(publication.id, %Paging{limit: 1, offset: 0})

      %Postgrex.Result{rows: rows, num_rows: 1, columns: columns} =
        Ecto.Adapters.SQL.query!(Oli.Repo, sql, params)

      record = to_record(hd(rows), columns)
      assert Map.get(record, "full_count") == 1
    end

    test "queries for full text", %{publication: publication} do
      {sql, params} =
        %Conditions{conditions: %Expression{fact: :text, operator: :contains, value: "question"}}
        |> QueryBuilder.build_for_paging(publication.id, %Paging{limit: 2, offset: 0})

      %Postgrex.Result{rows: rows, num_rows: 1, columns: columns} =
        Ecto.Adapters.SQL.query!(Oli.Repo, sql, params)

      record = to_record(hd(rows), columns)
      assert Map.get(record, "full_count") == 1
    end

    test "queries for activity type", %{publication: publication} do
      id = Oli.Activities.get_registration_by_slug("oli_multiple_choice").id

      # Verify the IN operator works
      {sql, params} =
        %Conditions{
          conditions: %Expression{fact: :type, operator: :contains, value: [id, id + 1]}
        }
        |> QueryBuilder.build_for_paging(publication.id, %Paging{limit: 2, offset: 0})

      %Postgrex.Result{rows: rows, num_rows: 2, columns: columns} =
        Ecto.Adapters.SQL.query!(Oli.Repo, sql, params)

      record = to_record(hd(rows), columns)
      assert Map.get(record, "full_count") == 4

      # Verify the exact match operator works, matching none
      {sql, params} =
        %Conditions{
          conditions: %Expression{fact: :type, operator: :contains, value: id + 1}
        }
        |> QueryBuilder.build_for_paging(publication.id, %Paging{limit: 2, offset: 0})

      %Postgrex.Result{num_rows: 0} = Ecto.Adapters.SQL.query!(Oli.Repo, sql, params)

      # Verify the exact match operator works, matching all
      {sql, params} =
        %Conditions{
          conditions: %Expression{fact: :type, operator: :contains, value: id}
        }
        |> QueryBuilder.build_for_paging(publication.id, %Paging{limit: 2, offset: 0})

      %Postgrex.Result{rows: rows, num_rows: 2, columns: columns} =
        Ecto.Adapters.SQL.query!(Oli.Repo, sql, params)

      record = to_record(hd(rows), columns)
      assert Map.get(record, "full_count") == 4
    end
  end

  defp to_record(row, columns) do
    Enum.zip(columns, row)
    |> Map.new()
  end
end
