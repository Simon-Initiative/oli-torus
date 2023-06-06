defmodule Oli.Interop.Ingest.Preprocessor do
  alias Oli.Interop.Ingest.State
  alias Oli.Interop.Ingest.Preprocessor.{Migrate, Parse, Verify, Validate}
  import Oli.Interop.Ingest.Preprocessor.Common

  @moduledoc """
  The ingest preprocesser adjusts and validates content for preparation to process
  for an ingestion.
  """

  @type_to_key [
                 {"Product", :products},
                 {"Bibentry", :bib_entries},
                 {"Activity", :activities},
                 {"Tag", :tags},
                 {"Page", :pages},
                 {"Objective", :objectives},
                 {"Alternatives", :alternatives}
               ]
               |> Map.new()

  @doc """
  Takes an in memory, unzipped representation of a course digest archive and preprocesses it to
  prepare for ingest.  During preprocessing, we:
  1. Parse the JSON
  2. Verify all internal idrefs
  3. Perform any necessary content adjustments / migrations
  4. Validate page and activity schemas

  Returns the modified ingest `%State` struct
  """
  def preprocess(%State{entries: nil} = state), do: state

  def preprocess(%State{} = state) do
    state
    |> Parse.process()
    |> Verify.process()
    |> bucket_by_resource_type()
    |> Migrate.process()
    |> Validate.process()
  end

  # Convert the list of tuples of unzipped entries into a map
  # where the keys are the ids (with the .json extension dropped)
  # and the values are the JSON content, parsed into maps
  defp bucket_by_resource_type(%State{resource_map: resource_map} = state) do
    known_keys = MapSet.new(well_known_keys())

    # Initialize all keys to empty lists
    state = Enum.reduce(@type_to_key, state, fn {_, key}, state -> Map.put(state, key, []) end)

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
end
