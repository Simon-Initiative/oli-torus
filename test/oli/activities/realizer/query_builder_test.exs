defmodule Oli.Activities.QueryBuilderTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Realizer.Conditions
  alias Oli.Activities.Realizer.QueryBuilder
  alias Oli.TestHelpers

  test "query with just an expression" do
    {:ok, contents} = TestHelpers.read_json_file("./test/oli/activities/realizer/valid1.json")

    assert {:ok, conditions} = Conditions.parse(contents)
    {test, []} = QueryBuilder.build(conditions, 1)

    assert test ==
             "SELECT revisons.* FROM published_resources LEFT JOIN revisions ON revisions.id = published_resources.revision_id WHERE (published_resources.publication_id = 1) AND (tags @> ARRAY[1])"
  end

  test "query with expressions within a conjunction clause" do
    {:ok, contents} = TestHelpers.read_json_file("./test/oli/activities/realizer/valid2.json")

    assert {:ok, conditions} = Conditions.parse(contents)
    {test, ["test"]} = QueryBuilder.build(conditions, 1)

    assert String.contains?(
             test,
             "((NOT (tags @> ARRAY[1])) AND (jsonb_path_match(objectives, 'exists($.** ? (@ == 2))')') AND activity_type_id != 3 AND (to_tsvector(content) @@ to_tsquery($1)))"
           )
  end

  test "nested clauses" do
    {:ok, contents} = TestHelpers.read_json_file("./test/oli/activities/realizer/valid3.json")

    assert {:ok, conditions} = Conditions.parse(contents)
    {test, ["test1", "test2"]} = QueryBuilder.build(conditions, 1)

    assert String.contains?(
             test,
             "(((NOT (tags @> ARRAY[1])) OR (to_tsvector(content) @@ to_tsquery($1))) AND (activity_type_id = 3 OR (to_tsvector(content) @@ to_tsquery($1))))"
           )
  end
end
