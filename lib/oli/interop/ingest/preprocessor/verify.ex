defmodule Oli.Interop.Ingest.Preprocessor.Verify do
  alias Oli.Interop.Ingest.State

  def process(%State{entries: entries} = state) do
    state
    |> State.notify_step_start(:validate_idrefs, (Enum.count(entries) - 3) |> max(0))
    |> validate_idrefs()
  end

  defp validate_idrefs(%State{resource_map: resource_map, errors: errors} = state) do
    all_id_refs =
      Enum.reduce(resource_map, [], fn {id, content}, acc ->
        State.notify_step_progress(state, "#{id}.json")
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
end
