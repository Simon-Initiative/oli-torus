defmodule Oli.Interop.IngestPreprocessor do
  alias Oli.Interop.Scrub
  alias Oli.Utils.SchemaResolver
  alias Oli.Resources.ContentMigrator
  alias Oli.Interop.IngestState

  @project_key "_project"
  @hierarchy_key "_hierarchy"
  @media_key "_media-manifest"

  @well_known_keys [@project_key, @hierarchy_key, @media_key]

  @type_to_key [
                 {"Product", :products},
                 {"Bibentry", :bib_entries},
                 {"Activity", :activities},
                 {"Tag", :tags},
                 {"Page", :pages},
                 {"Objective", :objectives}
               ]
               |> Map.new()

  @doc """
  Takes an in memory, unzipped representation of a course digest archive and preprocesses it to
  prepare for ingest.  During preprocessing, we:
  1. Validate all internal idrefs
  2. Validate page and activity schemas
  3. Perform any necessary content adjustments

  Returns `%PreprocessedIngest` struct
  """
  def preprocess(%IngestState{entries: nil} = state), do: state

  def preprocess(%IngestState{entries: entries} = state) do
    state
    |> IngestState.notify_step_start(:parse_json, Enum.count(entries))
    |> parse_json_entries()
    |> identify_well_known(@project_key, :project)
    |> identify_well_known(@hierarchy_key, :hierarchy)
    |> identify_well_known(@media_key, :media_manifest)
    |> IngestState.notify_step_start(:validate_idrefs, (Enum.count(entries) - 3) |> max(0))
    |> validate_idrefs()
    |> bucket_by_resource_type()
    |> IngestState.notify_step_start(:migrate_content, fn s ->
      Enum.count(s.activities) * 2 + Enum.count(s.pages)
    end)
    |> scrub_activity_contents()
    |> migrate_resource_content(:activities, :activity)
    |> migrate_resource_content(:pages, :page)
    |> IngestState.notify_step_start(:validate_activities, fn s ->
      Enum.count(s.activities)
    end)
    |> validate_json(:activities, "activity.schema.json")
    |> IngestState.notify_step_start(:validate_pages, fn s ->
      Enum.count(s.pages)
    end)
    |> validate_json(:pages, "page-content.schema.json", "content")
  end

  # Convert the list of tuples of unzipped entries into a map
  # where the keys are the ids (with the .json extension dropped)
  # and the values are the JSON content, parsed into maps
  defp parse_json_entries(%IngestState{entries: entries, errors: errors} = state) do
    {resource_map, error_map} =
      Enum.reduce(entries, {%{}, %{}}, fn {file, content}, {resource_map, error_map} ->
        IngestState.notify_step_progress(state, "#{file}.json")

        id_from_file = fn file ->
          file
          |> List.to_string()
          |> :filename.basename()
          |> String.replace_suffix(".json", "")
        end

        case Jason.decode(content) do
          {:ok, decoded} ->
            # Take the id from the attribute within the file content, unless
            # that id is not present (nil) or empty string. In that case,
            # use the file name to determine the id.  This allows us to avoid
            # issues of ids that contain unicode characters not being parsed
            # correctly from zip file entries.
            id =
              case Map.get(decoded, "id") do
                nil -> id_from_file.(file)
                "" -> id_from_file.(file)
                id -> id
              end

            {Map.put(resource_map, id, decoded), error_map}

          _ ->
            {resource_map,
             Map.put(
               error_map,
               id_from_file.(file),
               "failed to decode JSON in file '#{id_from_file.(file)}'"
             )}
        end
      end)

    %{state | resource_map: resource_map, errors: Map.values(error_map) ++ errors}
  end

  defp identify_well_known(
         %IngestState{resource_map: resource_map, errors: errors} = state,
         json_key,
         attr_key
       ) do
    case Map.get(resource_map, json_key) do
      nil ->
        %{state | errors: ["Could not locate required file #{json_key}.json in archive" | errors]}

      e ->
        Map.put(state, attr_key, e)
    end
  end

  defp validate_idrefs(%IngestState{resource_map: resource_map, errors: errors} = state) do
    all_id_refs =
      Enum.reduce(resource_map, [], fn {id, content}, acc ->
        IngestState.notify_step_progress(state, "#{id}.json")
        find_all_id_refs(id, content) ++ acc
      end)

    invalid_idrefs =
      Enum.filter(all_id_refs, fn {_, id_ref} ->
        !Map.has_key?(resource_map, id_ref)
      end)

    case invalid_idrefs do
      [] ->
        state

      invalid_idrefs ->
        %{
          state
          | errors:
              Enum.map(invalid_idrefs, fn {id, id_ref} ->
                "Resource [#{id}] contains an invalid idref [#{id_ref}]"
              end) ++ errors
        }
    end
  end

  defp find_all_id_refs(id, content) do
    idrefs_recursive_desc(id, content, [])
  end

  defp idrefs_recursive_desc(id, el, idrefs) do
    # if this element contains an idref, add it to the list

    idrefs =
      case el do
        %{"idref" => idref} ->
          [{id, idref} | idrefs]

        _ ->
          idrefs
      end

    # if this element contains children, recursively process them, otherwise return the list
    case el do
      %{"children" => children} ->
        Enum.reduce(children, idrefs, fn c, acc ->
          idrefs_recursive_desc(id, c, acc)
        end)

      _ ->
        idrefs
    end
  end

  defp bucket_by_resource_type(%IngestState{resource_map: resource_map} = state) do
    known_keys = MapSet.new(@well_known_keys)

    Enum.reduce(resource_map, state, fn {id, resource}, state ->
      case MapSet.member?(known_keys, id) do
        false ->
          case Map.get(@type_to_key, Map.get(resource, "type")) do
            nil ->
              Map.put(state, :errors, [
                "Unknown [#{Map.get(resource, "type")}] or missing type attribute in resource [#{id}]"
                | state.errors
              ])

            key ->
              Map.put(state, key, [{id, resource} | Map.get(state, key, [])])
          end

        true ->
          state
      end
    end)
  end

  defp migrate_resource_content(
         %IngestState{} = state,
         key,
         resource_type
       ) do
    migrated =
      Enum.reduce(Map.get(state, key), [], fn {id, resource}, all ->
        IngestState.notify_step_progress(state, "#{id}.json")

        case ContentMigrator.migrate(Map.get(resource, "content"), resource_type, to: :latest) do
          {:migrated, migrated} ->
            [{id, Map.put(resource, "content", migrated)} | all]

          {:skipped, _} ->
            [{id, resource} | all]
        end
      end)
      |> Map.new()

    Map.put(state, key, migrated)
  end

  defp validate_json(%IngestState{errors: errors} = state, key, schema_ref, attr \\ nil) do
    schema = SchemaResolver.schema(schema_ref)

    errors =
      Map.get(state, key)
      |> Enum.reduce(errors, fn {id, resource}, all_errors ->
        IngestState.notify_step_progress(state, "#{id}.json")

        content =
          case attr do
            nil -> resource
            attr -> Map.get(resource, attr)
          end

        case ExJsonSchema.Validator.validate(schema, content) do
          :ok ->
            all_errors

          {:error, errors} ->
            Enum.map(errors, fn {e, _} ->
              "Resource id [#{id}] failed JSON validation with error [#{e}]"
            end) ++ all_errors
        end
      end)

    %{state | errors: errors}
  end

  defp scrub_activity_contents(%IngestState{activities: activities} = state) do
    activities =
      Enum.reduce(activities, [], fn {id, %{"content" => content} = resource}, all ->
        IngestState.notify_step_progress(state, "#{id}.json")

        case Scrub.scrub(content) do
          {[], _} ->
            [{id, resource} | all]

          {_, changed} ->
            [{id, Map.put(resource, "content", changed)} | all]
        end
      end)
      |> Map.new()

    %{state | activities: activities}
  end
end
