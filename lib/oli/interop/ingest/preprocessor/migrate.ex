defmodule Oli.Interop.Ingest.Preprocessor.Migrate do
  alias Oli.Interop.Ingest.State

  alias Oli.Resources.ContentMigrator
  alias Oli.Interop.Scrub

  def process(%State{} = state) do
    state
    |> State.notify_step_start(:migrate_content, fn s ->
      Enum.count(s.activities) * 2 + Enum.count(s.pages)
    end)
    |> scrub_activity_contents()
    |> migrate_resource_content(:activities, :activity)
    |> migrate_resource_content(:pages, :page)
  end

  defp migrate_resource_content(
         %State{} = state,
         key,
         resource_type
       ) do
    migrated =
      Enum.reduce(Map.get(state, key), [], fn {id, resource}, all ->
        State.notify_step_progress(state, "#{id}.json")

        migrated =
          ContentMigrator.migrate(Map.get(resource, "content"), resource_type, to: :latest)

        [{id, Map.put(resource, "content", migrated)} | all]
      end)
      |> Map.new()

    Map.put(state, key, migrated)
  end

  defp scrub_activity_contents(%State{activities: activities} = state) do
    activities =
      Enum.reduce(activities, [], fn {id, %{"content" => content} = resource}, all ->
        State.notify_step_progress(state, "#{id}.json")

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
