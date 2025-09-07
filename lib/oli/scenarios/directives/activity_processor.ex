defmodule Oli.Scenarios.Directives.ActivityProcessor do
  @moduledoc """
  Processes inline activities in page content for scenarios.
  
  This module handles:
  - Creating inline activities with virtual_ids
  - Tracking virtual_id to revision mappings
  - Replacing inline activities with activity_reference blocks
  - Resolving virtual_id references to actual activity resource IDs
  """
  
  alias Oli.Activities
  alias Oli.TorusDoc.ActivityConverter
  
  @doc """
  Processes page YAML content to handle inline activities and virtual_id references.
  
  Returns {:ok, processed_yaml, updated_state} on success or {:error, reason} on failure.
  """
  def process_page_content(yaml_content, project_name, built_project, author, state) do
    # Parse the YAML string
    case YamlElixir.read_from_string(yaml_content) do
      {:ok, data} ->
        # Process the data to handle inline activities and virtual_id references
        case process_data(data, project_name, built_project, author, state) do
          {:ok, processed_data, updated_state} ->
            # Convert back to YAML string, preserving the structure
            yaml_string = convert_to_yaml_preserving_structure(processed_data)
            {:ok, yaml_string, updated_state}
            
          {:error, reason} ->
            {:error, reason}
        end
        
      {:error, _reason} ->
        # If we can't parse the YAML, just return it as-is
        {:ok, yaml_content, state}
    end
  end
  
  defp process_data(data, project_name, built_project, author, state) when is_map(data) do
    # Process blocks if this is the top-level page data
    case Map.get(data, "blocks") do
      blocks when is_list(blocks) ->
        case process_blocks(blocks, project_name, built_project, author, state) do
          {:ok, processed_blocks, updated_state} ->
            processed_data = Map.put(data, "blocks", processed_blocks)
            {:ok, processed_data, updated_state}
            
          error ->
            error
        end
        
      _ ->
        # No blocks to process
        {:ok, data, state}
    end
  end
  
  defp process_data(data, _project_name, _built_project, _author, state) do
    {:ok, data, state}
  end
  
  defp process_blocks(blocks, project_name, built_project, author, state) do
    # Process each block sequentially, threading the state through
    Enum.reduce_while(blocks, {:ok, [], state}, fn block, {:ok, acc_blocks, acc_state} ->
      case process_block(block, project_name, built_project, author, acc_state) do
        {:ok, processed_block, new_state} ->
          {:cont, {:ok, acc_blocks ++ [processed_block], new_state}}
          
        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end
  
  defp process_block(block, project_name, built_project, author, state) when is_map(block) do
    case block["type"] do
      "activity" ->
        process_activity_block(block, project_name, built_project, author, state)
        
      "activity_reference" ->
        process_activity_reference_block(block, project_name, state)
        
      "survey" ->
        process_survey_block(block, project_name, built_project, author, state)
        
      "group" ->
        process_group_block(block, project_name, built_project, author, state)
        
      _ ->
        # Other block types pass through unchanged
        {:ok, block, state}
    end
  end
  
  defp process_block(block, _project_name, _built_project, _author, state) do
    {:ok, block, state}
  end
  
  defp process_activity_block(block, project_name, built_project, author, state) do
    cond do
      # Inline activity with virtual_id
      Map.has_key?(block, "virtual_id") and Map.has_key?(block, "activity") ->
        virtual_id = block["virtual_id"]
        activity_data = block["activity"]
        
        # Check if we already have this virtual_id
        case Map.get(state.activity_virtual_ids, {project_name, virtual_id}) do
          nil ->
            # Create new activity using a simplified version of ActivityHandler logic
            case create_inline_activity(activity_data, built_project, author, virtual_id) do
              {:ok, revision} ->
                # Store the virtual_id mapping
                updated_state = %{state | 
                  activity_virtual_ids: Map.put(
                    state.activity_virtual_ids, 
                    {project_name, virtual_id}, 
                    revision
                  )
                }
                
                # Convert to activity_reference block
                reference_block = %{
                  "type" => "activity_reference",
                  "activity_id" => revision.resource_id
                }
                
                reference_block = 
                  if Map.has_key?(block, "id") do
                    Map.put(reference_block, "id", block["id"])
                  else
                    reference_block
                  end
                
                {:ok, reference_block, updated_state}
                
              {:error, reason} ->
                {:error, "Failed to create inline activity '#{virtual_id}': #{inspect(reason)}"}
            end
            
          existing_revision ->
            # Reuse existing activity - always use the reference, ignore the inline definition
            reference_block = %{
              "type" => "activity_reference",
              "activity_id" => existing_revision.resource_id
            }
            
            reference_block = 
              if Map.has_key?(block, "id") do
                Map.put(reference_block, "id", block["id"])
              else
                reference_block
              end
            
            {:ok, reference_block, state}
        end
        
      true ->
        # Regular activity block without virtual_id, pass through
        {:ok, block, state}
    end
  end
  
  defp process_activity_reference_block(block, project_name, state) do
    case Map.get(block, "virtual_id") do
      nil ->
        # No virtual_id, pass through
        {:ok, block, state}
        
      virtual_id ->
        # Look up the activity by virtual_id
        case Map.get(state.activity_virtual_ids, {project_name, virtual_id}) do
          nil ->
            {:error, "Activity with virtual_id '#{virtual_id}' not found"}
            
          activity_revision ->
            # Replace virtual_id with actual activity_id
            updated_block = block
              |> Map.delete("virtual_id")
              |> Map.put("activity_id", activity_revision.resource_id)
            
            {:ok, updated_block, state}
        end
    end
  end
  
  defp process_survey_block(block, project_name, built_project, author, state) do
    case Map.get(block, "blocks") do
      nested_blocks when is_list(nested_blocks) ->
        case process_blocks(nested_blocks, project_name, built_project, author, state) do
          {:ok, processed_blocks, updated_state} ->
            processed_block = Map.put(block, "blocks", processed_blocks)
            {:ok, processed_block, updated_state}
            
          error ->
            error
        end
        
      _ ->
        {:ok, block, state}
    end
  end
  
  defp process_group_block(block, project_name, built_project, author, state) do
    case Map.get(block, "blocks") do
      nested_blocks when is_list(nested_blocks) ->
        case process_blocks(nested_blocks, project_name, built_project, author, state) do
          {:ok, processed_blocks, updated_state} ->
            processed_block = Map.put(block, "blocks", processed_blocks)
            {:ok, processed_block, updated_state}
            
          error ->
            error
        end
        
      _ ->
        {:ok, block, state}
    end
  end
  
  defp create_inline_activity(activity_data, built_project, author, virtual_id) do
    # Get the activity type
    activity_type = activity_data["type"] || "oli_multiple_choice"
    
    # Get the activity registration
    case Activities.get_registration_by_slug(activity_type) do
      nil ->
        {:error, "Unknown activity type: #{activity_type}"}
        
      registration ->
        # Convert the activity data to Torus JSON format
        case convert_activity_to_json(activity_data, activity_type) do
          {:ok, activity_json} ->
            # Extract model and metadata
            model = Map.drop(activity_json, ["type", "objectives", "tags", "title"])
            
            # Get objectives - check if they are titles to resolve
            raw_objectives = get_objectives(activity_json)
            objectives = resolve_objective_titles(raw_objectives, built_project)
            
            # Get tags - check if they are titles to resolve
            raw_tags = Map.get(activity_json, "tags", [])
            tags = resolve_tag_titles(raw_tags, built_project)
            title = "Activity #{virtual_id}"
            
            # Create the activity using ActivityEditor
            # For test scenarios, we'll create it directly in memory
            create_test_activity(
              built_project,
              registration,
              author,
              model,
              objectives,
              tags,
              title
            )
            
          {:error, reason} ->
            {:error, reason}
        end
    end
  end
  
  defp convert_activity_to_json(activity_data, activity_type) do
    # Add the type if not present
    yaml_with_type = 
      if Map.has_key?(activity_data, "type") do
        activity_data
      else
        Map.put(activity_data, "type", activity_type)
      end
    
    # Extract objectives and tags before converting (they're not part of the activity model)
    objectives = Map.get(yaml_with_type, "objectives", [])
    tags = Map.get(yaml_with_type, "tags", [])
    
    # Remove objectives and tags from the data that goes to ActivityConverter
    yaml_without_metadata = yaml_with_type
      |> Map.delete("objectives")
      |> Map.delete("tags")
    
    # Convert data to properly formatted YAML string
    yaml_string = build_activity_yaml(yaml_without_metadata)
    
    # Use ActivityConverter to parse it
    case ActivityConverter.from_yaml(yaml_string) do
      {:ok, json} ->
        # Add objectives and tags back to the result
        {:ok, json 
          |> Map.put("objectives", objectives)
          |> Map.put("tags", tags)}
      error ->
        error
    end
  end
  
  defp create_test_activity(built_project, registration, author, model, objectives, tags, title) do
    # For test scenarios, create a simple revision structure
    # This mimics what ActivityEditor.create would do but without database operations
    
    # Parse the model to get part IDs and attach objectives to all parts
    objectives_map = case Oli.Activities.Model.parse(model) do
      {:ok, %{parts: parts}} ->
        Enum.reduce(parts, %{}, fn %{id: id}, m -> Map.put(m, id, objectives) end)
      _ ->
        %{}
    end
    
    attrs = %{
      title: title,
      resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
      activity_type_id: registration.id,
      author_id: author.id,
      content: model,
      objectives: objectives_map,
      tags: tags,
      graded: false,
      scope: "embedded"
    }
    
    # Create the resource and revision
    case Oli.Resources.create_resource_and_revision(attrs) do
      {:ok, %{revision: revision, resource: resource}} ->
        # Link the activity to the project
        {:ok, _} = Oli.Authoring.Course.create_project_resource(%{
          project_id: built_project.project.id,
          resource_id: resource.id
        })
        
        # If there's a working publication, add the activity to it
        case Oli.Publishing.project_working_publication(built_project.project.slug) do
          nil ->
            # No publication yet, that's ok
            {:ok, revision}
            
          publication ->
            # Add to the working publication
            {:ok, _} = Oli.Publishing.create_published_resource(%{
              publication_id: publication.id,
              resource_id: resource.id,
              revision_id: revision.id
            })
            {:ok, revision}
        end
        
      error ->
        error
    end
  end
  
  defp get_objectives(activity_json) do
    # Handle both string keys and atom keys
    case Map.get(activity_json, "objectives") || Map.get(activity_json, :objectives) do
      %{"attached" => objectives} when is_list(objectives) -> objectives
      objectives when is_list(objectives) -> objectives
      _ -> []
    end
  end
  
  defp resolve_objective_titles(objectives, built_project) do
    objectives_by_title = built_project.objectives_by_title || %{}
    
    Enum.map(objectives, fn obj ->
      cond do
        # If it's already a number (resource ID), keep it
        is_integer(obj) ->
          obj
          
        # If it's a string, try to resolve it as a title
        is_binary(obj) ->
          case Map.get(objectives_by_title, obj) do
            nil ->
              # Not found as title, maybe it's already a resource ID as string
              case Integer.parse(obj) do
                {id, ""} -> id
                _ -> nil  # Will be filtered out
              end
            objective_rev ->
              objective_rev.resource_id
          end
          
        true ->
          nil  # Will be filtered out
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end
  
  defp resolve_tag_titles(tags, built_project) do
    tags_by_title = built_project.tags_by_title || %{}
    
    Enum.map(tags, fn tag ->
      cond do
        # If it's already a number (resource ID), keep it
        is_integer(tag) ->
          tag
          
        # If it's a string, try to resolve it as a title
        is_binary(tag) ->
          case Map.get(tags_by_title, tag) do
            nil ->
              # Not found as title, maybe it's already a resource ID as string
              case Integer.parse(tag) do
                {id, ""} -> id
                _ -> nil  # Will be filtered out
              end
            tag_rev ->
              tag_rev.resource_id
          end
          
        true ->
          nil  # Will be filtered out
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end
  
  defp convert_to_yaml_preserving_structure(data) do
    # Build proper YAML structure
    lines = []
    
    # Add title if present
    lines = if data["title"] do
      ["title: \"#{escape_yaml_string(data["title"])}\"" | lines]
    else
      lines
    end
    
    # Add graded if present
    lines = if Map.has_key?(data, "graded") do
      ["graded: #{data["graded"]}" | lines]
    else
      lines
    end
    
    # Add blocks
    lines = if data["blocks"] do
      blocks_yaml = format_blocks_yaml(data["blocks"])
      ["blocks:\n#{blocks_yaml}" | lines]
    else
      lines
    end
    
    Enum.reverse(lines) |> Enum.join("\n")
  end
  
  defp format_blocks_yaml(blocks) when is_list(blocks) do
    blocks
    |> Enum.map(&format_single_block/1)
    |> Enum.join("\n")
  end
  
  defp format_blocks_yaml(_), do: ""
  
  defp format_single_block(block) when is_map(block) do
    lines = ["  - type: #{block["type"] || "prose"}"]
    
    # Add fields based on block type
    lines = case block["type"] do
      "prose" ->
        if block["body_md"] do
          ["    body_md: \"#{escape_yaml_string(block["body_md"])}\"" | lines]
        else
          lines
        end
        
      "survey" ->
        if block["blocks"] do
          nested_blocks = format_nested_blocks(block["blocks"], "    ")
          ["    blocks:\n#{nested_blocks}" | lines]
        else
          lines
        end
        
      "group" ->
        lines = if block["purpose"] do
          ["    purpose: \"#{block["purpose"]}\"" | lines]
        else
          lines
        end
        
        if block["blocks"] do
          nested_blocks = format_nested_blocks(block["blocks"], "    ")
          ["    blocks:\n#{nested_blocks}" | lines]
        else
          lines
        end
        
      "activity_reference" ->
        if block["activity_id"] do
          ["    activity_id: #{block["activity_id"]}" | lines]
        else
          lines
        end
        
      _ ->
        lines
    end
    
    Enum.reverse(lines) |> Enum.join("\n")
  end
  
  defp format_nested_blocks(blocks, base_indent) when is_list(blocks) do
    blocks
    |> Enum.map(fn block ->
      "#{base_indent}- type: #{block["type"] || "prose"}" <>
      format_nested_block_fields(block, base_indent)
    end)
    |> Enum.join("\n")
  end
  
  defp format_nested_blocks(_, _), do: ""
  
  defp format_nested_block_fields(block, indent) do
    fields = []
    
    fields = if block["body_md"] do
      ["\n#{indent}  body_md: \"#{escape_yaml_string(block["body_md"])}\"" | fields]
    else
      fields
    end
    
    fields = if block["activity_id"] do
      ["\n#{indent}  activity_id: #{block["activity_id"]}" | fields]
    else
      fields
    end
    
    Enum.reverse(fields) |> Enum.join("")
  end
  
  defp build_activity_yaml(activity_data) do
    # Build a proper YAML string for the activity
    lines = []
    
    # Add type - REQUIRED
    type = activity_data["type"] || "oli_multiple_choice"
    lines = ["type: \"#{type}\"" | lines]
    
    # Add stem_md
    lines = if activity_data["stem_md"] do
      ["stem_md: \"#{escape_yaml_string(activity_data["stem_md"])}\"" | lines]
    else
      lines
    end
    
    # Add choices if present
    lines = if activity_data["choices"] do
      choice_lines = activity_data["choices"] 
        |> Enum.with_index(1)
        |> Enum.map(fn {choice, index} ->
          build_choice_yaml(choice, index)
        end)
        |> Enum.join("\n")
      
      ["choices:\n#{choice_lines}" | lines]
    else
      lines
    end
    
    # Add other fields as needed
    lines = if activity_data["input_type"] do
      ["input_type: \"#{activity_data["input_type"]}\"" | lines]
    else
      lines
    end
    
    Enum.reverse(lines) |> Enum.join("\n")
  end
  
  defp build_choice_yaml(choice, _index) do
    lines = []
    
    # Add id
    id_line = if choice["id"] do
      "  - id: \"#{choice["id"]}\""
    else
      "  - id: \"#{generate_choice_id()}\""
    end
    lines = [id_line | lines]
    
    # Add body_md
    lines = if choice["body_md"] do
      ["    body_md: \"#{escape_yaml_string(choice["body_md"])}\"" | lines]
    else
      lines
    end
    
    # Add score
    score = Map.get(choice, "score", 0)
    lines = ["    score: #{score}" | lines]
    
    Enum.reverse(lines) |> Enum.join("\n")
  end
  
  defp generate_choice_id do
    Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
  end
  
  defp escape_yaml_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
  end
end