defmodule Oli.Utils.SchemaResolverTest do
  use Oli.DataCase

  describe "schema resolver" do
    test "activity-bank-selection schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/activity-bank-selection.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "activity-reference schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/activity-reference.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "group-content schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/group-content.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "model-element schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/model-element.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "page schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/page.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "resource-content schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/resource-content.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "selection schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/selection.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "slate-element schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/slate-element.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "structured-content schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/structured-content.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end
  end
end
