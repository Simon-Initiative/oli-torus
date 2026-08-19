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

    test "learning-objectives schema", _ do
      %ExJsonSchema.Schema.Root{} =
        "#{:code.priv_dir(:oli)}/schemas/v0-1-0/learning-objectives.schema.json"
        |> File.read!()
        |> Jason.decode!()
        |> ExJsonSchema.Schema.resolve()
    end

    test "page content schema accepts learning objectives only at the top level", _ do
      schema = Oli.Utils.SchemaResolver.resolve("page-content.schema.json")

      learning_objectives_element = %{
        "type" => "learning_objectives",
        "id" => "lo-element",
        "mode" => "introduction",
        "include_sub_objectives" => true,
        "learning_objectives" => [
          %{
            "resource_id" => 1,
            "enabled" => true,
            "revisit_pages" => [2],
            "practice_pages" => [3]
          }
        ]
      }

      valid_content = %{
        "version" => "0.1.0",
        "model" => [learning_objectives_element]
      }

      existing_content = %{
        "version" => "0.1.0",
        "model" => [
          %{
            "type" => "content",
            "id" => "content-block",
            "children" => [
              %{
                "type" => "p",
                "children" => [
                  %{"text" => "Existing content still validates"}
                ]
              }
            ]
          }
        ]
      }

      content_with_children = %{
        "version" => "0.1.0",
        "model" => [
          %{
            "type" => "learning_objectives",
            "id" => "lo-element-with-children",
            "mode" => "introduction",
            "include_sub_objectives" => true,
            "learning_objectives" => [],
            "children" => []
          }
        ]
      }

      nested_content = %{
        "version" => "0.1.0",
        "model" => [
          %{
            "type" => "group",
            "id" => "group",
            "layout" => "vertical",
            "purpose" => "none",
            "children" => [
              %{
                "type" => "learning_objectives",
                "id" => "nested-lo-element",
                "mode" => "summary",
                "include_sub_objectives" => true,
                "learning_objectives" => []
              }
            ]
          }
        ]
      }

      invalid_mode_content = %{
        "version" => "0.1.0",
        "model" => [Map.put(learning_objectives_element, "mode", "overview")]
      }

      missing_config_field_content = %{
        "version" => "0.1.0",
        "model" => [
          Map.put(learning_objectives_element, "learning_objectives", [
            %{
              "resource_id" => 1,
              "enabled" => true,
              "revisit_pages" => [2]
            }
          ])
        ]
      }

      extra_config_field_content = %{
        "version" => "0.1.0",
        "model" => [
          Map.put(learning_objectives_element, "learning_objectives", [
            %{
              "resource_id" => 1,
              "enabled" => true,
              "revisit_pages" => [2],
              "practice_pages" => [3],
              "unexpected" => "field"
            }
          ])
        ]
      }

      invalid_id_content = %{
        "version" => "0.1.0",
        "model" => [
          Map.put(learning_objectives_element, "learning_objectives", [
            %{
              "resource_id" => 0,
              "enabled" => true,
              "revisit_pages" => [2],
              "practice_pages" => [3]
            }
          ])
        ]
      }

      invalid_recommendation_content = %{
        "version" => "0.1.0",
        "model" => [
          Map.put(learning_objectives_element, "learning_objectives", [
            %{
              "resource_id" => 1,
              "enabled" => true,
              "revisit_pages" => [2, 2],
              "practice_pages" => [0]
            }
          ])
        ]
      }

      assert :ok = ExJsonSchema.Validator.validate(schema, valid_content)
      assert :ok = ExJsonSchema.Validator.validate(schema, existing_content)
      assert {:error, _} = ExJsonSchema.Validator.validate(schema, content_with_children)
      assert {:error, _} = ExJsonSchema.Validator.validate(schema, nested_content)
      assert {:error, _} = ExJsonSchema.Validator.validate(schema, invalid_mode_content)
      assert {:error, _} = ExJsonSchema.Validator.validate(schema, missing_config_field_content)
      assert {:error, _} = ExJsonSchema.Validator.validate(schema, extra_config_field_content)
      assert {:error, _} = ExJsonSchema.Validator.validate(schema, invalid_id_content)
      assert {:error, _} = ExJsonSchema.Validator.validate(schema, invalid_recommendation_content)
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
