defmodule Oli.Validation.ContentValidator do
  @moduledoc """
  Validates content elements using JSON Schema validation against the
  content-element.schema.json specification.
  """

  @content_schema_path "priv/schemas/v0-1-0/content-element.schema.json"

  @doc """
  Validates all content elements within an activity model.

  This function traverses the activity structure and validates content in:
  - stem.content
  - choices[].content
  - authoring.parts[].hints[].content
  - authoring.parts[].feedback[].content

  ## Parameters
  - `activity_map`: The activity data as a map with string keys

  ## Returns
  - `:ok` if all content is valid
  - `{:error, {path, errors}}` if validation fails, where path indicates
    the location of the invalid content and errors contains the validation details
  """
  def validate_activity_content(activity_map) when is_map(activity_map) do
    schema = load_content_schema()

    with :ok <- validate_stem_content(activity_map, schema),
         :ok <- validate_choices_content(activity_map, schema),
         :ok <- validate_authoring_content(activity_map, schema) do
      :ok
    else
      error -> error
    end
  end

  def validate_activity_content(_), do: {:error, "Activity must be a map"}

  # Private functions

  defp load_content_schema do
    schema_path = Path.join(File.cwd!(), @content_schema_path)

    case File.read(schema_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, schema} -> ExJsonSchema.Schema.resolve(schema)
          {:error, reason} -> raise "Failed to decode content schema: #{inspect(reason)}"
        end

      {:error, reason} ->
        raise "Failed to read content schema from #{schema_path}: #{inspect(reason)}"
    end
  end

  defp validate_stem_content(activity_map, schema) do
    case get_in(activity_map, ["stem", "content"]) do
      nil ->
        :ok

      content when is_list(content) ->
        validate_content_list(content, schema, "stem.content")

      _ ->
        {:error, {"stem.content", ["Content must be a list"]}}
    end
  end

  defp validate_choices_content(activity_map, schema) do
    case Map.get(activity_map, "choices", []) do
      choices when is_list(choices) ->
        choices
        |> Enum.with_index()
        |> Enum.reduce_while(:ok, fn {choice, index}, :ok ->
          case validate_choice_content(choice, schema, index) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
        end)

      _ ->
        {:error, {"choices", ["Choices must be a list"]}}
    end
  end

  defp validate_choice_content(choice, schema, index) when is_map(choice) do
    case Map.get(choice, "content") do
      nil ->
        :ok

      content when is_list(content) ->
        validate_content_list(content, schema, "choices[#{index}].content")

      _ ->
        {:error, {"choices[#{index}].content", ["Content must be a list"]}}
    end
  end

  defp validate_choice_content(_, _, index) do
    {:error, {"choices[#{index}]", ["Choice must be a map"]}}
  end

  defp validate_authoring_content(activity_map, schema) do
    case get_in(activity_map, ["authoring", "parts"]) do
      nil ->
        :ok

      parts when is_list(parts) ->
        parts
        |> Enum.with_index()
        |> Enum.reduce_while(:ok, fn {part, index}, :ok ->
          case validate_part_content(part, schema, index) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
        end)

      _ ->
        {:error, {"authoring.parts", ["Parts must be a list"]}}
    end
  end

  defp validate_part_content(part, schema, part_index) when is_map(part) do
    with :ok <- validate_hints_content(part, schema, part_index),
         :ok <- validate_responses_content(part, schema, part_index) do
      :ok
    else
      error -> error
    end
  end

  defp validate_part_content(_, _, part_index) do
    {:error, {"authoring.parts[#{part_index}]", ["Part must be a map"]}}
  end

  defp validate_hints_content(part, schema, part_index) do
    case Map.get(part, "hints", []) do
      hints when is_list(hints) ->
        hints
        |> Enum.with_index()
        |> Enum.reduce_while(:ok, fn {hint, hint_index}, :ok ->
          case validate_hint_content(hint, schema, part_index, hint_index) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
        end)

      _ ->
        {:error, {"authoring.parts[#{part_index}].hints", ["Hints must be a list"]}}
    end
  end

  defp validate_hint_content(hint, schema, part_index, hint_index) when is_map(hint) do
    case Map.get(hint, "content") do
      nil ->
        :ok

      content when is_list(content) ->
        validate_content_list(
          content,
          schema,
          "authoring.parts[#{part_index}].hints[#{hint_index}].content"
        )

      _ ->
        {:error,
         {"authoring.parts[#{part_index}].hints[#{hint_index}].content",
          ["Content must be a list"]}}
    end
  end

  defp validate_hint_content(_, _, part_index, hint_index) do
    {:error, {"authoring.parts[#{part_index}].hints[#{hint_index}]", ["Hint must be a map"]}}
  end

  defp validate_responses_content(part, schema, part_index) do
    case Map.get(part, "responses", []) do
      responses when is_list(responses) ->
        responses
        |> Enum.with_index()
        |> Enum.reduce_while(:ok, fn {response, response_index}, :ok ->
          case validate_response_content(response, schema, part_index, response_index) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
        end)

      _ ->
        {:error, {"authoring.parts[#{part_index}].responses", ["Responses must be a list"]}}
    end
  end

  defp validate_response_content(response, schema, part_index, response_index)
       when is_map(response) do
    case Map.get(response, "feedback") do
      nil ->
        :ok

      feedback when is_map(feedback) ->
        validate_feedback_content(feedback, schema, part_index, response_index)

      _ ->
        {:error,
         {"authoring.parts[#{part_index}].responses[#{response_index}].feedback",
          ["Feedback must be a map"]}}
    end
  end

  defp validate_response_content(_, _, part_index, response_index) do
    {:error,
     {"authoring.parts[#{part_index}].responses[#{response_index}]", ["Response must be a map"]}}
  end

  defp validate_feedback_content(feedback, schema, part_index, response_index)
       when is_map(feedback) do
    case Map.get(feedback, "content") do
      nil ->
        :ok

      content when is_list(content) ->
        validate_content_list(
          content,
          schema,
          "authoring.parts[#{part_index}].responses[#{response_index}].feedback.content"
        )

      _ ->
        {:error,
         {"authoring.parts[#{part_index}].responses[#{response_index}].feedback.content",
          ["Content must be a list"]}}
    end
  end

  defp validate_content_list(content_list, schema, path) when is_list(content_list) do
    content_list
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {element, index}, :ok ->
      case validate_content_element(element, schema) do
        :ok -> {:cont, :ok}
        {:error, errors} -> {:halt, {:error, {"#{path}[#{index}]", errors}}}
      end
    end)
  end

  defp validate_content_list(_, _, path) do
    {:error, {path, ["Content must be a list"]}}
  end

  # Custom content element validation that's more strict than the schema
  defp validate_content_element(element, _schema) when is_map(element) do
    case Map.get(element, "type") do
      nil ->
        # Check if it's a text node (just has "text" field)
        case Map.get(element, "text") do
          text when is_binary(text) ->
            :ok

          _ ->
            {:error,
             [
               "Content element must have either a 'type' field or be a text node with 'text' field"
             ]}
        end

      type when is_binary(type) ->
        validate_typed_element(element, type)

      _ ->
        {:error, ["Content element 'type' must be a string"]}
    end
  end

  defp validate_content_element(_, _) do
    {:error, ["Content element must be a map"]}
  end

  # Known valid content element types from the schema
  @valid_types MapSet.new([
                 # Text block types
                 "p",
                 "h1",
                 "h2",
                 "h3",
                 "h4",
                 "h5",
                 "h6",
                 # List types
                 "ul",
                 "ol",
                 "li",
                 "dl",
                 "dd",
                 "dt",
                 # Media types
                 "img",
                 "img_inline",
                 "youtube",
                 "video",
                 "audio",
                 "iframe",
                 # Table types
                 "table",
                 "tr",
                 "td",
                 "th",
                 "tc",
                 # Semantic types
                 "callout",
                 "callout_inline",
                 "definition",
                 "figure",
                 "dialog",
                 "conjugation",
                 # Code types
                 "code",
                 "code_line",
                 # Math types
                 "math",
                 "math_line",
                 "formula",
                 "formula_inline",
                 # Interactive types
                 "input_ref",
                 "popup",
                 "foreign",
                 # Link types
                 "a",
                 "page_link",
                 "cite",
                 # Other types
                 "blockquote"
               ])

  defp validate_typed_element(element, type) do
    if MapSet.member?(@valid_types, type) do
      validate_element_structure(element, type)
    else
      {:error, ["Unknown content element type: '#{type}'"]}
    end
  end

  defp validate_element_structure(element, type) do
    case type do
      type when type in ["p", "h1", "h2", "h3", "h4", "h5", "h6"] ->
        validate_text_block(element)

      type when type in ["ul", "ol"] ->
        validate_list(element)

      "li" ->
        validate_list_item(element)

      "table" ->
        validate_table(element)

      type when type in ["tr", "td", "th"] ->
        validate_table_element(element)

      type when type in ["img", "img_inline"] ->
        validate_image(element)

      _ ->
        # For other types, just check that it's a proper map
        # This is where we'd add more specific validations as needed
        :ok
    end
  end

  defp validate_text_block(%{"type" => _, "children" => children}) when is_list(children) do
    :ok
  end

  defp validate_text_block(_), do: {:error, ["Text block elements must have a 'children' array"]}

  defp validate_list(%{"type" => _, "children" => children}) when is_list(children) do
    :ok
  end

  defp validate_list(_), do: {:error, ["List elements must have a 'children' array"]}

  defp validate_list_item(%{"type" => "li"}) do
    # List items can have optional children
    :ok
  end

  defp validate_table(%{"type" => "table", "children" => children}) when is_list(children) do
    :ok
  end

  defp validate_table(_), do: {:error, ["Table elements must have a 'children' array"]}

  defp validate_table_element(%{"type" => _, "children" => children}) when is_list(children) do
    :ok
  end

  defp validate_table_element(_),
    do: {:error, ["Table row/cell elements must have a 'children' array"]}

  defp validate_image(%{"type" => _}) do
    # Images have optional attributes like src, alt, etc.
    :ok
  end
end
