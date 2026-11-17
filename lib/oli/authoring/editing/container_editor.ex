defmodule Oli.Authoring.Editing.ContainerEditor do
  @moduledoc """
  This module provides high-level editing facilities for project
  containers, mainly around adding and removing and reording
  the items within a container.

  """

  import Oli.Authoring.Editing.Utils

  alias Oli.Resources.Revision
  alias Oli.Resources
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Publishing.ChangeTracker
  alias Oli.ScopedFeatureFlags
  alias Oli.Repo
  alias Oli.Authoring.Broadcaster
  alias Oli.Authoring.Editing.AdaptiveDuplication
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Activities
  alias Oli.Resources.ScoringStrategy

  @adaptive_content_defaults %{
    "advancedAuthoring" => true,
    "advancedDelivery" => true,
    "displayApplicationChrome" => false,
    "model" => []
  }

  @flowchart_custom_defaults %{
    "contentMode" => "flowchart",
    "defaultScreenHeight" => 540,
    "defaultScreenWidth" => 1200,
    "enableHistory" => true,
    "maxScore" => 0,
    "responsiveLayout" => true,
    "themeId" => "torus-default-light",
    "totalScore" => 0
  }

  @expert_custom_defaults %{
    "contentMode" => "expert",
    "defaultScreenHeight" => 540,
    "defaultScreenWidth" => 1200,
    "enableHistory" => true,
    "maxScore" => 0,
    "responsiveLayout" => true,
    "themeId" => "torus-default-light",
    "totalScore" => 0
  }

  @doc """
  Lists all top level resource revisions contained in a container.
  """
  def list_all_container_children(container, %Project{} = project) do
    AuthoringResolver.from_resource_id(project.slug, container.children)
    |> Repo.preload([:resource, :author])
  end

  @doc """
  Creates and adds a new page or container as a child of a container.
  """
  def add_new(
        container,
        %{objectives: _, children: _, content: _, title: _} = attrs,
        %Author{} = author,
        %Project{} = project
      ) do
    attrs =
      Map.merge(attrs, %{
        author_id: author.id
      })

    # We want to ensure that the creation and attachment either
    # all succeeds or all fails
    result =
      Repo.transaction(fn ->
        with {:ok, %{revision: revision}} <-
               Oli.Authoring.Course.create_and_attach_resource(project, attrs),
             {:ok, _} <- ChangeTracker.track_revision(project.slug, revision),
             {:ok, _} <- append_to_container(container, project.slug, revision, author) do
          revision
        else
          {:error, e} -> Repo.rollback(e)
        end
      end)

    {status, _} = result

    if status == :ok && container != nil do
      broadcast_update(container.resource_id, project.slug)
    end

    result
  end

  def add_new(
        container,
        type,
        scored,
        %Author{} = author,
        %Project{} = project,
        numberings \\ nil,
        opts \\ %{}
      )
      when is_binary(type) do
    adaptive_mode = normalize_adaptive_mode(opts)

    attrs = %{
      tags: [],
      objectives: %{"attached" => []},
      children: [],
      content: page_content(type, adaptive_mode),
      title:
        case type do
          "Adaptive" ->
            case scored do
              "Scored" -> adaptive_assessment_title(adaptive_mode)
              "Unscored" -> adaptive_page_title(adaptive_mode)
            end

          "Basic" ->
            case scored do
              "Scored" -> "New Assessment"
              "Unscored" -> "New Page"
            end

          "Container" ->
            new_container_name(numberings, container)
        end,
      graded:
        case type do
          "Container" ->
            false

          _ ->
            case scored do
              "Scored" -> true
              "Unscored" -> false
            end
        end,
      ai_enabled:
        case type do
          "Container" ->
            nil

          _ ->
            case scored do
              "Scored" -> false
              "Unscored" -> true
            end
        end,
      max_attempts:
        case type do
          "Container" ->
            nil

          _ ->
            case scored do
              "Scored" -> 5
              "Unscored" -> 0
            end
        end,
      recommended_attempts:
        case type do
          "Container" ->
            nil

          _ ->
            case scored do
              "Scored" -> 5
              "Unscored" -> 0
            end
        end,
      scoring_strategy_id:
        case type do
          "Adaptive" -> ScoringStrategy.get_id_by_type("best")
          "Basic" -> ScoringStrategy.get_id_by_type("best")
          "Container" -> nil
        end,
      resource_type_id:
        case type do
          "Adaptive" -> Oli.Resources.ResourceType.id_for_page()
          "Basic" -> Oli.Resources.ResourceType.id_for_page()
          "Container" -> Oli.Resources.ResourceType.id_for_container()
        end
    }

    add_new(
      container,
      attrs,
      author,
      project
    )
  end

  defp normalize_adaptive_mode(%{"adaptive_mode" => mode}) when mode in ["flowchart", "expert"],
    do: mode

  defp normalize_adaptive_mode(%{adaptive_mode: mode}) when mode in ["flowchart", "expert"],
    do: mode

  defp normalize_adaptive_mode(_), do: nil

  defp adaptive_page_title("flowchart"), do: "New Simple Author Page"
  defp adaptive_page_title("expert"), do: "New Advanced Author Page"
  defp adaptive_page_title(_), do: "New Adaptive Page"

  defp adaptive_assessment_title("flowchart"), do: "New Simple Author Assessment"
  defp adaptive_assessment_title("expert"), do: "New Advanced Author Assessment"
  defp adaptive_assessment_title(_), do: "New Adaptive Assessment"

  defp page_content("Adaptive", "flowchart") do
    @adaptive_content_defaults
    |> Map.put("custom", @flowchart_custom_defaults)
    |> Map.put("additionalStylesheets", ["/css/delivery_adaptive_themes_flowchart.css"])
  end

  defp page_content("Adaptive", "expert") do
    @adaptive_content_defaults
    |> Map.put("custom", @expert_custom_defaults)
    |> Map.put("additionalStylesheets", ["/css/delivery_adaptive_themes_default_light.css"])
  end

  defp page_content("Adaptive", _adaptive_mode), do: @adaptive_content_defaults

  defp page_content(_type, _adaptive_mode) do
    %{
      "version" => "0.1.0",
      "model" => []
    }
  end

  def broadcast_update(resource_id, project_slug) do
    updated_container = AuthoringResolver.from_resource_id(project_slug, resource_id)
    Broadcaster.broadcast_revision(updated_container, project_slug)
  end

  @doc """
    Duplicates a page within its project.
    A true deep-copy of all the content is made. Resources and Revisions are created instead of simply referenced.
  """
  def duplicate_page(
        container,
        page_id,
        %Author{} = author,
        %Project{} = project
      )
      when is_nil(container) or is_struct(container, Revision) do
    original_page =
      Resources.get_revision!(page_id)
      |> Map.from_struct()

    cond do
      Resources.ResourceType.is_adaptive_page(original_page) and
        ScopedFeatureFlags.can_access?(:adaptive_duplication, author, project) and
          adaptive_duplication_supported?(original_page) ->
        AdaptiveDuplication.duplicate(project, original_page.resource_id,
          container: container,
          author: author
        )

      Resources.ResourceType.is_adaptive_page(original_page) and
          adaptive_duplication_supported?(original_page) ->
        {:error, {:adaptive_duplication, :disabled}}

      true ->
        new_page_attrs =
          original_page
          |> Map.drop([:slug, :inserted_at, :updated_at, :resource_id, :resource])
          |> Map.put(:title, "#{original_page.title} (copy)")
          |> Map.put(:content, nil)
          |> Map.put(:previous_revision_id, nil)
          |> then(fn map ->
            if is_nil(map.legacy) do
              map
            else
              Map.put(map, :legacy, Map.from_struct(original_page.legacy))
            end
          end)

        Repo.transaction(fn ->
          with {:ok, created_revision} <- add_new(container, new_page_attrs, author, project),
               {:ok, model_duplicated_activities} <-
                 deep_copy_activities(
                   original_page.content,
                   project.slug,
                   author
                 ),
               {:ok, updated_revision} <-
                 Resources.update_revision(created_revision, %{
                   content: model_duplicated_activities
                 }) do
            updated_revision
          else
            {:error, e} -> Repo.rollback(e)
          end
        end)
    end
  end

  defp adaptive_duplication_supported?(original_page) do
    case AdaptiveDuplication.extract_adaptive_screen_refs(original_page.content) do
      {:ok, _screen_refs} -> true
      _ -> false
    end
  end

  def deep_copy_activities(model, project_slug, author) do
    {mapped, result} =
      Oli.Resources.PageContent.map_reduce(model, {:ok}, fn e, {status}, _tr_context ->
        case e do
          %{"type" => "activity-reference"} = ref ->
            case deep_copy_activity(ref, project_slug, author) do
              {:ok, updated_activity_reference} ->
                {updated_activity_reference, {status}}

              {:error, _} ->
                {ref, {:error}}
            end

          other ->
            {other, {status}}
        end
      end)

    case result do
      {:ok} ->
        {:ok, mapped}

      {:error} ->
        {:error, :failed_to_duplicate_activities}
    end
  end

  def deep_copy_activity(%{"type" => "activity-reference"} = item, project_slug, author) do
    activity_revision = AuthoringResolver.from_resource_id(project_slug, item["activity_id"])

    deep_copy_activity_revision(item, project_slug, author, activity_revision)
  end

  def deep_copy_activity(item, _project_slug, _author), do: {:ok, item}

  @doc """
  Copies an activity-reference node from a revision that has already been resolved.

  This keeps `deep_copy_activity/3` behavior available for ordinary callers while
  allowing repair tools to batch-resolve activity revisions before cloning many
  sources. The create path below remains the same tested duplication mechanism.
  """
  def deep_copy_activity_revision(
        %{"type" => "activity-reference"} = item,
        project_slug,
        author,
        %Revision{} = activity_revision
      ) do
    activity_type = Activities.get_registration(activity_revision.activity_type_id)

    case ActivityEditor.create(
           project_slug,
           activity_type.slug,
           author,
           activity_revision.content,
           [],
           "embedded",
           activity_revision.title,
           activity_revision.objectives,
           activity_revision.tags,
           activity_revision.learning_model_parameters
         ) do
      {:ok, {revision, _}} ->
        {:ok,
         %{
           "id" => item["id"],
           "type" => "activity-reference",
           "children" => [],
           "activity_id" => revision.resource_id
         }}

      {:error, error} ->
        {:error, error}
    end
  end

  def deep_copy_activity_revision(item, _project_slug, _author, _activity_revision),
    do: {:ok, item}

  # if no container is specified then this is a no-op
  defp append_to_container(nil, _project_slug, _revision_to_attach, _author), do: {:ok, nil}

  defp append_to_container(container, project_slug, revision_to_attach, author) do
    append = %{
      children: container.children ++ [revision_to_attach.resource_id],
      author_id: author.id
    }

    with {:ok, _} <- ChangeTracker.track_revision(project_slug, container, append),
         {:ok, restored_revision} <-
           maybe_restore_deleted_revision(project_slug, revision_to_attach, author) do
      {:ok, restored_revision}
    end
  end

  defp maybe_restore_deleted_revision(project_slug, revision_to_attach, author) do
    case revision_to_attach.deleted do
      true ->
        ChangeTracker.track_revision(project_slug, revision_to_attach, %{
          deleted: false,
          author_id: author.id
        })

      _ ->
        {:ok, revision_to_attach}
    end
  end
end
