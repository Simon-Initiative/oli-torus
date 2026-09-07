defmodule Oli.Interop.Ingest.Processor.Alternatives do
  require Logger

  alias Oli.Interop.Ingest.State
  alias Oli.Resources.Alternatives, as: AlternativesStrategy
  import Oli.Interop.Ingest.Processor.Common

  def process(%State{} = state) do
    State.notify_step_start(state, :alternatives)
    |> create_revisions(
      :alternatives,
      Oli.Resources.ResourceType.id_for_alternatives(),
      &mapper/3
    )
  end

  def mapper(%State{slug_prefix: slug_prefix}, resource_id, resource) do
    legacy_id = Map.get(resource, "legacyId", nil)
    legacy_path = Map.get(resource, "legacyPath", nil)
    title = Map.get(resource, "title", "missing title")

    content =
      resource
      |> Map.get("content", %{})
      |> canonical_content()

    %{
      slug: Oli.Utils.Slug.slug_with_prefix(slug_prefix, title),
      legacy: %Oli.Resources.Legacy{id: legacy_id, path: legacy_path},
      resource_id: resource_id,
      tags: {:placeholder, :tags},
      title: title,
      content: content,
      author_id: {:placeholder, :author_id},
      objectives: {:placeholder, :objectives},
      resource_type_id: {:placeholder, :resource_type_id},
      inserted_at: {:placeholder, :now},
      updated_at: {:placeholder, :now}
    }
  end

  defp canonical_content(content) when is_map(content) do
    strategy = Map.get(content, "strategy", "user_section_preference")

    case AlternativesStrategy.normalize_strategy(strategy) do
      {:ok, canonical} ->
        Map.put(content, "strategy", canonical)

      {:error, :unsupported_strategy} ->
        Logger.warning(
          "Unsupported Alternatives strategy encountered during ingest: #{inspect(strategy, limit: 5, printable_limit: 100)}"
        )

        Map.put(content, "strategy", strategy)
    end
  end
end
