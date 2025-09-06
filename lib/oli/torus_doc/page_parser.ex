defmodule Oli.TorusDoc.PageParser do
  @moduledoc """
  Parser for TorusDoc Page YAML format.

  Parses a page YAML structure into an intermediate representation
  that can be converted to different output formats (Torus JSON, markdown, etc).
  """

  @doc """
  Parses a page YAML string into a structured representation.

  Returns `{:ok, page}` on success or `{:error, reason}` on failure.
  """
  def parse(yaml_string) when is_binary(yaml_string) do
    case YamlElixir.read_from_string(yaml_string) do
      {:ok, data} ->
        parse_page(data)

      {:error, reason} ->
        {:error, "YAML parsing failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Parses a page data structure (already parsed from YAML).
  
  This is used internally and by TorusDoc for processing page documents.
  """
  def parse_page(data) when is_map(data) do
    with :ok <- validate_page_type(data),
         {:ok, blocks} <- parse_blocks(data["blocks"] || []) do
      {:ok,
       %{
         type: data["type"],
         id: data["id"],
         title: data["title"],
         graded: data["graded"] || false,
         blocks: blocks,
         metadata: extract_metadata(data)
       }}
    end
  end

  def parse_page(_), do: {:error, "Invalid page structure: expected a map"}

  defp validate_page_type(%{"type" => "page"}), do: :ok

  defp validate_page_type(%{"type" => type}),
    do: {:error, "Invalid page type: #{type}, expected 'page'"}

  defp validate_page_type(_), do: {:error, "Missing page type"}

  # Generic helper for parsing block lists with proper error handling and performance
  defp parse_block_list(blocks, parser_fn, error_prefix) when is_list(blocks) do
    blocks
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {block, index}, {:ok, acc} ->
      case parser_fn.(block) do
        {:ok, parsed_block} ->
          {:cont, {:ok, [parsed_block | acc]}}

        {:error, reason} ->
          {:halt, {:error, "#{error_prefix} #{index + 1}: #{reason}"}}
      end
    end)
    |> case do
      {:ok, reversed_blocks} -> {:ok, Enum.reverse(reversed_blocks)}
      error -> error
    end
  end

  defp parse_blocks(blocks) when is_list(blocks) do
    parse_block_list(blocks, &parse_block/1, "Error in block")
  end

  defp parse_blocks(_), do: {:error, "Blocks must be a list"}

  defp parse_block(%{"type" => "prose"} = block) do
    parse_prose_block(block)
  end

  defp parse_block(%{"type" => "survey"} = block) do
    parse_survey_block(block)
  end

  defp parse_block(%{"type" => "group"} = block) do
    parse_group_block(block)
  end

  defp parse_block(%{"type" => "activity"} = block) do
    parse_activity_block(block)
  end

  defp parse_block(%{"type" => "bank-selection"} = block) do
    parse_bank_selection_block(block)
  end

  defp parse_block(%{"type" => "activity_reference"} = block) do
    parse_activity_reference_block(block)
  end

  defp parse_block(%{"type" => type} = _block) do
    {:error, "Unknown block type: #{type}. Supported types: prose, survey, group, activity_reference"}
  end

  defp parse_block(_) do
    {:error, "Block must have a 'type' field"}
  end

  defp parse_prose_block(%{"body_md" => markdown} = block) when is_binary(markdown) do
    {:ok,
     %{
       type: "prose",
       body_md: markdown,
       id: Map.get(block, "id")
     }}
  end

  defp parse_prose_block(_) do
    {:error, "Prose block must have a 'body_md' field with markdown content"}
  end

  defp parse_activity_block(block) do
    # For inline activities, we store the activity definition directly
    # For activity references, we just store the reference
    cond do
      Map.has_key?(block, "activity") ->
        # This is a nested inline activity definition
        activity_data = block["activity"]
        
        # Also support prompt_md as an alias for stem_md
        activity_data = 
          if Map.has_key?(activity_data, "prompt_md") && !Map.has_key?(activity_data, "stem_md") do
            activity_data
            |> Map.put("stem_md", activity_data["prompt_md"])
            |> Map.delete("prompt_md")
          else
            activity_data
          end
        
        # Pass virtual_id if present
        virtual_id = Map.get(block, "virtual_id")
        parse_inline_activity(activity_data, block["id"], virtual_id)

      Map.has_key?(block, "stem_md") ->
        # This is an inline activity definition at the top level
        # We need to handle the fact that there might be two "type" fields:
        # one for the block type and one for the activity type
        activity_type = Map.get(block, "activity_type") || Map.get(block, "activityType")

        # Build the activity data with the proper type field
        activity_data =
          block
          # Remove the block type
          |> Map.drop(["type"])
          # Use activity type or default
          |> Map.put("type", activity_type || "oli_multi_choice")

        # Pass virtual_id if present
        virtual_id = Map.get(block, "virtual_id")
        parse_inline_activity(activity_data, block["id"], virtual_id)

      Map.has_key?(block, "activity_id") || Map.has_key?(block, "virtual_id") ->
        # This is a reference to an existing activity
        reference = %{
          type: "activity_reference",
          id: block["id"]
        }
        
        # Add activity_id or virtual_id
        reference = 
          cond do
            Map.has_key?(block, "activity_id") ->
              Map.put(reference, :activity_id, block["activity_id"])
            Map.has_key?(block, "virtual_id") ->
              Map.put(reference, :virtual_id, block["virtual_id"])
            true ->
              reference
          end
        
        {:ok, reference}

      true ->
        {:error,
         "Activity block must have either 'activity' (inline), 'stem_md' (inline) or 'activity_id' (reference)"}
    end
  end

  defp parse_inline_activity(activity_data, block_id, virtual_id) do
    # Parse the activity definition using ActivityParser
    # The block should contain all activity fields
    alias Oli.TorusDoc.ActivityParser

    case ActivityParser.parse_activity(activity_data) do
      {:ok, activity} ->
        result = %{
          type: "activity_inline",
          activity: activity,
          id: block_id
        }
        
        # Add virtual_id if present
        result = if virtual_id do
          Map.put(result, :virtual_id, virtual_id)
        else
          result
        end
        
        {:ok, result}

      {:error, reason} ->
        {:error, "Failed to parse inline activity: #{reason}"}
    end
  end

  defp parse_activity_reference_block(%{"virtual_id" => virtual_id} = block) when is_binary(virtual_id) do
    {:ok,
     %{
       type: "activity_reference",
       virtual_id: virtual_id,
       id: Map.get(block, "id")
     }}
  end
  
  defp parse_activity_reference_block(%{"activity_id" => activity_id} = block) when is_integer(activity_id) do
    {:ok,
     %{
       type: "activity_reference",
       activity_id: activity_id,
       id: Map.get(block, "id")
     }}
  end
  
  defp parse_activity_reference_block(_) do
    {:error, "Activity reference block must have either 'virtual_id' or 'activity_id' field"}
  end

  defp parse_survey_block(block) do
    with {:ok, nested_blocks} <- parse_survey_blocks(block["blocks"] || []) do
      {:ok,
       %{
         type: "survey",
         id: block["id"],
         blocks: nested_blocks
       }}
    end
  end

  defp parse_group_block(block) do
    with :ok <- validate_group_purpose(block["purpose"]),
         :ok <- validate_group_layout(block["layout"]),
         {:ok, nested_blocks} <- parse_group_blocks(block["blocks"] || []) do
      {:ok,
       %{
         type: "group",
         id: block["id"],
         purpose: block["purpose"] || "none",
         layout: block["layout"] || "vertical",
         pagination_mode: block["pagination_mode"] || "normal",
         audience: block["audience"],
         blocks: nested_blocks
       }}
    end
  end

  defp parse_bank_selection_block(block) do
    with {:ok, clauses} <- parse_bank_clauses(block["clauses"] || []) do
      {:ok,
       %{
         type: "bank_selection",
         id: block["id"],
         count: block["count"] || 1,
         points: block["points"] || 0,
         clauses: clauses
       }}
    end
  end

  defp parse_bank_clauses(clauses) when is_list(clauses) do
    clauses
    |> Enum.map(&parse_bank_clause/1)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, clause}, {:ok, acc} -> {:cont, {:ok, [clause | acc]}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, reversed_clauses} -> {:ok, Enum.reverse(reversed_clauses)}
      error -> error
    end
  end

  defp parse_bank_clauses(_), do: {:error, "Bank selection clauses must be a list"}

  defp parse_bank_clause(%{"field" => field, "op" => op, "value" => value}) do
    {:ok,
     %{
       field: field,
       op: op,
       value: value
     }}
  end

  defp parse_bank_clause(_) do
    {:error, "Bank clause must have 'field', 'op', and 'value' fields"}
  end

  @valid_purposes ~w(none checkpoint didigetthis labactivity learnbydoing learnmore 
                     manystudentswonder myresponse quiz simulation walkthrough example)

  defp validate_group_purpose(nil), do: :ok
  defp validate_group_purpose(purpose) when purpose in @valid_purposes, do: :ok

  defp validate_group_purpose(purpose) do
    {:error,
     "Invalid group purpose: #{purpose}. Valid purposes: #{Enum.join(@valid_purposes, ", ")}"}
  end

  @valid_layouts ~w(vertical deck)

  defp validate_group_layout(nil), do: :ok
  defp validate_group_layout(layout) when layout in @valid_layouts, do: :ok

  defp validate_group_layout(layout) do
    {:error, "Invalid group layout: #{layout}. Valid layouts: #{Enum.join(@valid_layouts, ", ")}"}
  end

  defp parse_survey_blocks(blocks) when is_list(blocks) do
    parse_block_list(blocks, &parse_survey_nested_block/1, "Error in survey block")
  end

  defp parse_survey_blocks(_), do: {:error, "Survey blocks must be a list"}

  defp parse_group_blocks(blocks) when is_list(blocks) do
    parse_block_list(blocks, &parse_group_nested_block/1, "Error in group block")
  end

  defp parse_group_blocks(_), do: {:error, "Group blocks must be a list"}

  defp parse_survey_nested_block(%{"type" => "prose"} = block) do
    parse_prose_block(block)
  end

  defp parse_survey_nested_block(%{"type" => "activity"} = block) do
    parse_activity_block(block)
  end

  defp parse_survey_nested_block(%{"type" => "bank-selection"} = block) do
    parse_bank_selection_block(block)
  end

  defp parse_survey_nested_block(%{"type" => "activity_reference"} = block) do
    parse_activity_reference_block(block)
  end

  defp parse_survey_nested_block(%{"type" => type} = _block) do
    {:error, "Unknown survey block type: #{type}"}
  end

  defp parse_survey_nested_block(_) do
    {:error, "Survey nested block must have a 'type' field"}
  end

  defp parse_group_nested_block(%{"type" => "prose"} = block) do
    parse_prose_block(block)
  end

  defp parse_group_nested_block(%{"type" => "survey"} = _block) do
    {:error, "Groups cannot contain surveys"}
  end

  defp parse_group_nested_block(%{"type" => "group"} = _block) do
    {:error, "Groups cannot contain other groups"}
  end

  defp parse_group_nested_block(%{"type" => "activity"} = block) do
    parse_activity_block(block)
  end

  defp parse_group_nested_block(%{"type" => "bank-selection"} = block) do
    parse_bank_selection_block(block)
  end

  defp parse_group_nested_block(%{"type" => "activity_reference"} = block) do
    parse_activity_reference_block(block)
  end

  defp parse_group_nested_block(%{"type" => type} = _block) do
    {:error, "Unknown group block type: #{type}"}
  end

  defp parse_group_nested_block(_) do
    {:error, "Group nested block must have a 'type' field"}
  end

  defp extract_metadata(data) do
    data
    |> Map.drop(["type", "id", "title", "graded", "blocks"])
    |> case do
      empty when empty == %{} -> nil
      metadata -> metadata
    end
  end
end
