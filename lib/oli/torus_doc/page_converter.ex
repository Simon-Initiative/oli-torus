defmodule Oli.TorusDoc.PageConverter do
  @moduledoc """
  Converts parsed TorusDoc page structures to Torus JSON format.

  This module is responsible for transforming the intermediate representation
  from PageParser into the Torus JSON schema format.
  """

  alias Oli.TorusDoc.Markdown.MarkdownParser

  # Generic helper for converting block lists with proper error handling and performance
  defp convert_block_list(blocks, converter_fn) when is_list(blocks) do
    blocks
    |> Enum.reduce_while({:ok, []}, fn block, {:ok, acc} ->
      case converter_fn.(block) do
        {:ok, converted} ->
          {:cont, {:ok, [converted | acc]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, reversed_blocks} -> {:ok, Enum.reverse(reversed_blocks)}
      error -> error
    end
  end

  @doc """
  Converts a parsed page structure to Torus JSON format.

  Returns `{:ok, json}` on success or `{:error, reason}` on failure.
  """
  def to_torus_json(parsed_page) when is_map(parsed_page) do
    with {:ok, model} <- convert_blocks(parsed_page.blocks) do
      {:ok,
       %{
         "type" => "Page",
         "id" => parsed_page.id || generate_id(),
         "title" => parsed_page.title || "Untitled Page",
         "isGraded" => parsed_page.graded,
         "content" => %{
           "version" => "0.1.0",
           "model" => model
         },
         "objectives" => %{
           "attached" => []
         },
         "tags" => [],
         "unresolvedReferences" => []
       }}
    end
  end

  def to_torus_json(_) do
    {:error, "Invalid parsed page structure"}
  end

  defp convert_blocks(blocks) when is_list(blocks) do
    blocks
    |> Enum.reduce_while({:ok, []}, fn block, {:ok, acc} ->
      case convert_block(block) do
        {:ok, converted} ->
          {:cont, {:ok, [converted | acc]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, reversed_blocks} -> {:ok, Enum.reverse(List.flatten(reversed_blocks))}
      error -> error
    end
  end

  defp convert_blocks(_), do: {:error, "Blocks must be a list"}

  defp convert_block(%{type: "prose", body_md: markdown} = block) when is_binary(markdown) do
    case MarkdownParser.parse(markdown) do
      {:ok, content_elements} ->
        {:ok,
         %{
           "type" => "content",
           "id" => block[:id] || generate_id(),
           "children" => content_elements
         }}

      {:error, reason} ->
        {:error, "Failed to parse markdown in prose block: #{reason}"}
    end
  end

  defp convert_block(%{type: "prose"} = _block) do
    {:error, "Failed to parse markdown in prose block: body_md must be a string"}
  end

  defp convert_block(%{type: "survey"} = survey) do
    with {:ok, children} <- convert_survey_blocks(survey.blocks) do
      {:ok,
       %{
         "type" => "survey",
         "id" => survey.id || generate_id(),
         "children" => children
       }}
    end
  end

  defp convert_block(%{type: "group"} = group) do
    with {:ok, children} <- convert_group_blocks(group.blocks) do
      result = %{
        "type" => "group",
        "id" => group.id || generate_id(),
        "purpose" => group.purpose,
        "layout" => group.layout,
        "children" => children
      }

      # Add optional fields if present
      result =
        if group.pagination_mode != "normal" do
          Map.put(result, "paginationMode", group.pagination_mode)
        else
          result
        end

      result =
        if group.audience do
          Map.put(result, "audience", group.audience)
        else
          result
        end

      {:ok, result}
    end
  end

  defp convert_block(%{type: "activity_reference"} = block) do
    # This is a reference to an existing activity
    reference = %{
      "type" => "activity-reference",
      "id" => block.id || generate_id()
    }
    
    # Add activitySlug or virtual_id
    reference = 
      cond do
        Map.has_key?(block, :activity_id) ->
          Map.put(reference, "activitySlug", block.activity_id)
        Map.has_key?(block, :virtual_id) ->
          Map.put(reference, "_virtual_id", block.virtual_id)
        true ->
          reference
      end
    
    {:ok, reference}
  end

  defp convert_block(%{type: "activity_inline"} = block) do
    # This is an inline activity definition
    # In Torus, activities are typically stored separately and referenced
    # For now, we'll convert it to an activity reference with the activity data
    # stored in a separate structure
    alias Oli.TorusDoc.ActivityConverter

    case ActivityConverter.to_torus_json(block.activity) do
      {:ok, activity_json} ->
        # Return both the reference and the activity definition
        # The caller will need to handle storing the activity separately
        reference = %{
          "type" => "activity-reference",
          "id" => block.id || generate_id(),
          "activitySlug" => activity_json["id"],
          "_inline_activity" => activity_json
        }
        
        # Add virtual_id if present
        reference = 
          if Map.has_key?(block, :virtual_id) do
            Map.put(reference, "_virtual_id", block.virtual_id)
          else
            reference
          end
        
        {:ok, reference}

      {:error, reason} ->
        {:error, "Failed to convert inline activity: #{reason}"}
    end
  end

  defp convert_block(%{type: "bank_selection"} = block) do
    result = %{
      "type" => "selection",
      "id" => block.id || generate_id(),
      "logic" => convert_bank_logic(block.clauses),
      "count" => block.count
    }

    # Only include pointsPerActivity if points > 0
    result =
      if block.points > 0 do
        Map.put(result, "pointsPerActivity", block.points)
      else
        result
      end

    {:ok, result}
  end

  defp convert_block(%{type: type}) do
    {:error, "Unknown block type for conversion: #{type}"}
  end

  defp convert_survey_blocks(blocks) when is_list(blocks) do
    convert_block_list(blocks, &convert_survey_nested_block/1)
  end

  defp convert_survey_blocks(_), do: {:error, "Survey blocks must be a list"}

  defp convert_group_blocks(blocks) when is_list(blocks) do
    convert_block_list(blocks, &convert_group_nested_block/1)
  end

  defp convert_group_blocks(_), do: {:error, "Group blocks must be a list"}

  defp convert_survey_nested_block(%{type: "prose", body_md: markdown} = block)
       when is_binary(markdown) do
    case MarkdownParser.parse(markdown) do
      {:ok, content_elements} ->
        {:ok,
         %{
           "type" => "content",
           "id" => block[:id] || generate_id(),
           "children" => content_elements
         }}

      {:error, reason} ->
        {:error, "Failed to parse markdown in survey prose block: #{reason}"}
    end
  end

  defp convert_survey_nested_block(%{type: "prose"} = _block) do
    {:error, "Failed to parse markdown in survey prose block: body_md must be a string"}
  end

  defp convert_survey_nested_block(%{type: "activity_reference"} = block) do
    convert_block(block)
  end

  defp convert_survey_nested_block(%{type: "activity_inline"} = block) do
    convert_block(block)
  end

  defp convert_survey_nested_block(%{type: "bank_selection"} = block) do
    convert_block(block)
  end

  defp convert_survey_nested_block(%{type: "bank_selection_placeholder"}) do
    convert_block(%{type: "bank_selection_placeholder"})
  end

  defp convert_survey_nested_block(%{type: type}) do
    {:error, "Unknown survey block type for conversion: #{type}"}
  end

  defp convert_group_nested_block(%{type: "prose", body_md: markdown} = block)
       when is_binary(markdown) do
    case MarkdownParser.parse(markdown) do
      {:ok, content_elements} ->
        {:ok,
         %{
           "type" => "content",
           "id" => block[:id] || generate_id(),
           "children" => content_elements
         }}

      {:error, reason} ->
        {:error, "Failed to parse markdown in group prose block: #{reason}"}
    end
  end

  defp convert_group_nested_block(%{type: "prose"} = _block) do
    {:error, "Failed to parse markdown in group prose block: body_md must be a string"}
  end

  defp convert_group_nested_block(%{type: "survey"} = survey) do
    convert_block(survey)
  end

  defp convert_group_nested_block(%{type: "group"} = group) do
    # Groups can be nested within groups
    convert_block(group)
  end

  defp convert_group_nested_block(%{type: "activity_reference"} = block) do
    convert_block(block)
  end

  defp convert_group_nested_block(%{type: "activity_inline"} = block) do
    convert_block(block)
  end

  defp convert_group_nested_block(%{type: "bank_selection"} = block) do
    convert_block(block)
  end

  defp convert_group_nested_block(%{type: "bank_selection_placeholder"}) do
    convert_block(%{type: "bank_selection_placeholder"})
  end

  defp convert_group_nested_block(%{type: type}) do
    {:error, "Unknown group block type for conversion: #{type}"}
  end

  defp generate_id do
    # Generate a unique ID
    "gen_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  @doc """
  Convenience function that parses YAML and converts to Torus JSON in one step.
  """
  def from_yaml(yaml_string) do
    alias Oli.TorusDoc.PageParser

    with {:ok, parsed} <- PageParser.parse(yaml_string),
         {:ok, json} <- to_torus_json(parsed) do
      {:ok, json}
    end
  end

  defp convert_bank_logic(clauses) when is_list(clauses) do
    %{
      "conditions" => %{
        "fact" => "all",
        "children" => Enum.map(clauses, &convert_bank_clause/1)
      }
    }
  end

  defp convert_bank_logic(_), do: %{"conditions" => %{"fact" => "all", "children" => []}}

  defp convert_bank_clause(%{field: field, op: op, value: value}) do
    %{
      "fact" => field,
      "operator" => convert_operator(op),
      "value" => value
    }
  end

  defp convert_operator("includes"), do: "contains"
  defp convert_operator("equals"), do: "equal"
  defp convert_operator("not_equals"), do: "notEqual"
  defp convert_operator("greater_than"), do: "greaterThan"
  defp convert_operator("less_than"), do: "lessThan"
  defp convert_operator(op), do: op
end
