defmodule Oli.Utils.SchemaResolverTest do
  use Oli.DataCase

  describe "schema resolver" do
    test "activity-bank-selection schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/activity-bank-selection.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "activity-reference schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/activity-reference.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "group-content schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/group-content.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "model-element schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/model-element.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "page schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/page.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "resource-content schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/resource-content.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "selection schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/selection.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "structured-content schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/structured-content.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end
  end
end
