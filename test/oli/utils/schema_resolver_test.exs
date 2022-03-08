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

    test "content-group schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/content-group.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "content-element schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/content-element.schema.json"
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

    test "selection schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/selection.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "content-block schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/content-block.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "adaptive-activity schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/adaptive-activity.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "activity schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/activity.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end
  end
end
