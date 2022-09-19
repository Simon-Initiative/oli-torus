defmodule Oli.Interop.Ingest.Preprocessor.Parse do
  alias Oli.Interop.Ingest.State
  import Oli.Interop.Ingest.Preprocessor.Common

  def process(%State{entries: entries} = state) do
    state
    |> State.notify_step_start(:parse_json, Enum.count(entries))
    |> parse_json_entries()
    |> identify_well_known(project_key(), :project_details)
    |> identify_well_known(hierarchy_key(), :hierarchy)
    |> identify_well_known(media_key(), :media_manifest)
  end

  defp parse_json_entries(%State{entries: entries, errors: errors} = state) do
    {resource_map, error_map} =
      Enum.reduce(entries, {%{}, %{}}, fn {file, content}, {resource_map, error_map} ->
        State.notify_step_progress(state, "#{file}.json")

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
         %State{resource_map: resource_map, errors: errors} = state,
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
end
