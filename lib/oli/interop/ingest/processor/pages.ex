defmodule Oli.Interop.Ingest.Processor.Pages do
  alias Oli.Interop.Ingest.State
  alias Oli.Interop.Ingest.Processing.Rewiring
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  import Oli.Interop.Ingest.Processor.Common

  def process(%State{} = state) do
    State.notify_step_start(state, :pages)
    |> create_revisions(
      :pages,
      Oli.Resources.ResourceType.id_for_page(),
      &mapper/3
    )
  end

  defp get_explanation_strategy(%{"type" => type, "set_num_attempts" => set_num_attempts}) do
    %Oli.Resources.ExplanationStrategy{
      type: String.to_atom(type),
      set_num_attempts: set_num_attempts
    }
  end

  defp get_explanation_strategy(true) do
    %Oli.Resources.ExplanationStrategy{type: :after_max_resource_attempts_exhausted}
  end

  defp get_explanation_strategy(false) do
    %Oli.Resources.ExplanationStrategy{type: :after_set_num_attempts, set_num_attempts: 2}
  end

  # Read the collab space config in a robust manner, falling back to defaults if
  # the entire collabSpace key is missing or if any sub keys are missing
  defp read_collab_space(%{"collabSpace" => nil}), do: read_collab_space(%{"collabSpace" => %{}})

  defp read_collab_space(%{"collabSpace" => config}) do
    # Read the status in a way that falls back to the proper default
    # status if no status is specified or if an unsupported status is specified
    default_status_str = CollabSpaceConfig.default_status() |> Atom.to_string()
    candidate_status = Map.get(config, "status", default_status_str)

    status =
      case CollabSpaceConfig.status_values()
           |> Enum.map(fn a -> Atom.to_string(a) end)
           |> Enum.any?(fn status_str -> status_str == candidate_status end) do
        true -> String.to_existing_atom(candidate_status)
        _ -> CollabSpaceConfig.default_status()
      end

    %CollabSpaceConfig{
      status: status,
      threaded: Map.get(config, "threaded", true),
      auto_accept: Map.get(config, "auto_accept", true),
      show_full_history: Map.get(config, "show_full_history", true),
      participation_min_replies: Map.get(config, "participation_min_replies", 0),
      participation_min_posts: Map.get(config, "participation_min_posts", 0)
    }
  end

  defp read_collab_space(_), do: read_collab_space(%{"collabSpace" => %{}})

  defp mapper(state, resource_id, resource) do
    legacy_id = Map.get(resource, "legacyId", nil)
    legacy_path = Map.get(resource, "legacyPath", nil)

    title =
      case Map.get(resource, "title") do
        nil -> "Missing title"
        "" -> "Empty title"
        title -> title
      end

    graded = Map.get(resource, "isGraded", false)

    content = Map.get(resource, "content")

    content =
      Rewiring.rewire_activity_references(content, state.legacy_to_resource_id_map)
      |> Rewiring.rewire_report_activity_references(state.legacy_to_resource_id_map)
      |> Rewiring.rewire_bank_selections(state.legacy_to_resource_id_map)
      |> Rewiring.rewire_citation_references(state.legacy_to_resource_id_map)
      |> Rewiring.rewire_alternatives_groups(state.legacy_to_resource_id_map)

    scoring_strategy_id =
      Map.get(resource, "scoringStrategyId", Oli.Resources.ScoringStrategy.get_id_by_type("best"))

    explanation_strategy =
      resource
      |> Map.get("explanationStrategy", graded)
      |> get_explanation_strategy()

    max_attempts = Map.get(resource, "maxAttempts", if(graded, do: 5, else: 0))

    recommended_attempts = Map.get(resource, "recommendedAttempts", 5)

    full_progress_pct = Map.get(resource, "fullProgressPct", 100)

    retake_mode = Map.get(resource, "retakeMode", "normal") |> String.to_atom()

    assessment_mode = Map.get(resource, "assessmentMode", "traditional") |> String.to_atom()

    %{
      slug: Oli.Utils.Slug.slug_with_prefix(state.slug_prefix, title),
      legacy: %Oli.Resources.Legacy{id: legacy_id, path: legacy_path},
      resource_id: resource_id,
      tags: transform_tags(resource, state.legacy_to_resource_id_map),
      title: title,
      objectives: %{
        "attached" =>
          Enum.map(resource["objectives"], fn id ->
            case Map.get(state.legacy_to_resource_id_map, id) do
              nil -> nil
              id -> id
            end
          end)
          |> Enum.filter(fn f -> !is_nil(f) end)
      },
      content: content,
      author_id: {:placeholder, :author_id},
      children: {:placeholder, :children},
      resource_type_id: {:placeholder, :resource_type_id},
      activity_type_id: Map.get(state.registration_by_subtype, Map.get(resource, "subType")),
      scoring_strategy_id: scoring_strategy_id,
      explanation_strategy: explanation_strategy,
      collab_space_config: read_collab_space(resource),
      purpose: Map.get(resource, "purpose", "foundation") |> String.to_existing_atom(),
      relates_to:
        Map.get(resource, "relatesTo", []) |> Enum.map(fn id -> String.to_integer(id) end),
      graded: graded,
      max_attempts: max_attempts,
      intro_content: Map.get(resource, "introContent", %{}),
      intro_video: Map.get(resource, "introVideo"),
      poster_image: Map.get(resource, "posterImage"),
      recommended_attempts: recommended_attempts,
      duration_minutes: Map.get(resource, "durationMinutes"),
      full_progress_pct: full_progress_pct,
      retake_mode: retake_mode,
      assessment_mode: assessment_mode,
      inserted_at: {:placeholder, :now},
      updated_at: {:placeholder, :now}
    }
  end
end
