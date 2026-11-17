defmodule Oli.Authoring.Editing.ActivityEditor do
  @moduledoc """
  This module provides content editing facilities for activities.

  """

  import Oli.Authoring.Editing.Utils
  import Ecto.Query, warn: false

  require Logger

  alias Oli.Resources
  alias Oli.Resources.Revision
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Editing.ActivityContext
  alias Oli.Publishing
  alias Oli.Activities
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course
  alias Oli.Repo
  alias Oli.Activities.Transformers
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.ContentMigrator
  alias Oli.Authoring.LearningObjectives.ProjectClassifier
  alias ExAws.S3

  @default_embedded_bundle_s3_concurrency 8
  @default_embedded_bundle_s3_timeout_ms 15_000
  @embedded_bundle_source_prefixes [
    "media/webcontent/custom_activity/",
    "webcontent/custom_activity/"
  ]
  @embedded_bundle_repair_overlay_keys [
    "base",
    "src",
    "title",
    "stem",
    "authoring",
    "bibrefs",
    "scoringStrategy"
  ]

  # Filters out objective ids that are no longer present in the list of all objectives
  @doc """
  Filters an objectives map so that only objective ids present in `all_objectives`
  remain for each part. Non-map inputs are passed through unchanged or defaulted
  to an empty map, keeping this function safe for varied shapes seen in legacy data.
  """
  def filter_objectives_to_existing(objectives, all_objectives) when is_map(objectives) do
    valid_ids =
      all_objectives
      |> Enum.map(& &1.id)
      |> MapSet.new()

    objectives
    |> Enum.reduce(%{}, fn {part_id, obj_ids}, acc ->
      filtered_ids =
        obj_ids
        |> List.wrap()
        |> Enum.filter(fn id -> MapSet.member?(valid_ids, id) end)

      Map.put(acc, part_id, filtered_ids)
    end)
  end

  def filter_objectives_to_existing(objectives, _all_objectives) when is_list(objectives) do
    objectives
  end

  def filter_objectives_to_existing(_objectives, _all_objectives), do: %{}

  @doc """
  Retrieves a list of activity resources.

  Returns:

  .`{:ok, [%Revision{}]}` when the revision is retrieved
  .`{:error, {:not_found}}` if the project is not found
  """
  @spec retrieve_bulk(String.t(), any(), any()) ::
          {:ok, %Revision{}} | {:error, {:not_found}}
  def retrieve_bulk(project_slug, activity_ids, author) when is_list(activity_ids) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project) do
      case AuthoringResolver.from_resource_id(project_slug, activity_ids) do
        nil -> {:error, {:not_found}}
        revisions -> {:ok, revisions}
      end
    else
      error -> error
    end
  end

  @doc """
  Retrieves an activity resource.

  Returns:

  .`{:ok, %Revision{}}` when the revision is retrieved
  .`{:error, {:not_found}}` if the project or resource is not found
  """
  @spec retrieve(String.t(), any(), any()) ::
          {:ok, %Revision{}} | {:error, {:not_found}}
  def retrieve(project_slug, activity_id, author) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project) do
      case AuthoringResolver.from_resource_id(project_slug, activity_id) do
        nil -> {:error, {:not_found}}
        revision -> {:ok, revision}
      end
    else
      error -> error
    end
  end

  @spec repair_embedded_bundle(String.t(), any(), Author.t(), map()) ::
          {:ok, map()} | {:error, {:not_found}} | {:error, {:not_authorized}} | {:error, any()}
  def repair_embedded_bundle(project_slug, activity_id, author, model) when is_map(model) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, revision} <-
           AuthoringResolver.from_resource_id(project_slug, activity_id) |> trap_nil() do
      persisted_model = revision.content

      case repairable_embedded_bundle?(persisted_model) do
        true ->
          persisted_model
          |> clone_embedded_bundle()
          |> apply_embedded_bundle_repair_overlay(model)

        false ->
          {:error, {:invalid_request, "Bundle repair is not available for this activity."}}
      end
    else
      error -> error
    end
  end

  def repair_embedded_bundle(_project_slug, _activity_id, _author, _model),
    do: {:error, {:invalid_update_field}}

  @doc """
  Creates a new secondary document for an activity.

  Returns:

  .`{:ok, %Activity{}}` when the creation processes succeeds
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this project
  .`{:error, {:invalid_update_field}}` if the update contains an invalid field
  .`{:error, {:error}}` unknown error
  """
  @spec create_secondary(String.t(), String.t(), %Author{}, map()) ::
          {:ok, %Revision{}}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:not_authorized}}
          | {:error, {:invalid_update_field}}
  def create_secondary(project_slug, activity_id, author, update) do
    Repo.transaction(fn ->
      with {:ok, validated_update} <- validate_creation_request(update),
           {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
           {:ok} <- authorize_user(author, project),
           {:ok, _} <-
             AuthoringResolver.from_resource_id(project_slug, activity_id) |> trap_nil(),
           {:ok, publication} <-
             Publishing.project_working_publication(project_slug) |> trap_nil(),
           {:ok, secondary_revision} <-
             create_secondary_revision(activity_id, author.id, validated_update),
           {:ok, _} <-
             Course.create_project_resource(%{
               project_id: project.id,
               resource_id: secondary_revision.resource_id
             })
             |> trap_nil(),
           {:ok, _mapping} <-
             Publishing.create_published_resource(%{
               publication_id: publication.id,
               resource_id: secondary_revision.resource_id,
               revision_id: secondary_revision.id
             }) do
        secondary_revision
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  defp create_secondary_revision(primary_id, author_id, attrs) do
    {:ok, resource} = Resources.create_new_resource()

    with_type =
      Map.put(attrs, "resource_type_id", Oli.Resources.ResourceType.id_for_secondary())
      |> Map.put("resource_id", resource.id)
      |> Map.put("author_id", author_id)
      |> Map.put("primary_resource_id", primary_id)

    Resources.create_revision(with_type)
  end

  # if objectives to attach are provided, attach them to all parts
  defp attach_objectives(model, objectives_to_attach, objective_map) when objective_map == %{},
    do: attach_objectives_to_all_parts(model, objectives_to_attach)

  # if the objectives map is already built and can be used directly
  defp attach_objectives(_model, _objectives = [], objective_map), do: {:ok, objective_map}

  # takes the model of the activity to be created and a list of objective ids and
  # creates a map of all part ids to objective resource ids
  defp attach_objectives_to_all_parts(model, objectives) do
    result =
      case Oli.Activities.Model.parse(model) do
        {:ok, %{parts: parts}} ->
          %{
            "objectives" =>
              Enum.reduce(parts, %{}, fn %{id: id}, m -> Map.put(m, id, objectives) end)
          }
          |> Map.get("objectives")

        {:error, _e} ->
          %{}
      end

    {:ok, result}
  end

  @doc """
  Validates the fields of an activity update, or of a list of them: only `objectives`, `title`,
  `content`, `authoring`, `releaseLock`, `resource_id`, and `tags`, or a sole `deep_link_result`
  token. Returns `{:ok, update}` or `{:error, {:invalid_update_field}}`.
  """
  def validate_request(update) when is_list(update) do
    all_valid? =
      Enum.map(update, fn u -> validate_request(u) end)
      |> Enum.all?(fn result ->
        case result do
          {:ok, _} -> true
          _ -> false
        end
      end)

    case all_valid? do
      true -> {:ok, update}
      _ -> {:error, {:invalid_update_field}}
    end
  end

  # A signed-result save must contain only its token; its tool configuration is
  # derived server-side instead of being mixed with client-supplied content changes.
  def validate_request(%{"deep_link_result" => token} = update) do
    case is_binary(token) and map_size(update) == 1 do
      true -> {:ok, update}
      false -> {:error, {:invalid_update_field}}
    end
  end

  def validate_request(update) do
    # Ensure that only these top-level keys are present
    allowed = MapSet.new(~w"objectives title content authoring releaseLock resource_id tags")

    case Map.keys(update)
         |> Enum.all?(fn k -> MapSet.member?(allowed, k) end) do
      false -> {:error, {:invalid_update_field}}
      true -> {:ok, update}
    end
  end

  defp validate_creation_request(update) do
    # Ensure that content, title and objectives are present.  Provide defaults if not.
    update = Map.put(update, "content", Map.get(update, "content", %{}))
    update = Map.put(update, "title", Map.get(update, "title", "default"))
    update = Map.put(update, "objectives", Map.get(update, "objectives", %{}))

    validate_request(update)
  end

  @doc """
  Attempts to process a request to create a new activity.

  Returns:

  .`{:ok, {%Revision{}, transformed_content}}` when the creation processes succeeds
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to create this activity
  .`{:error, {:error}}` unknown error
  """
  @spec create(String.t(), String.t(), %Author{}, %{}, []) ::
          {:ok, {%Revision{}, map()}}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:not_authorized}}
  def create(
        project_slug,
        activity_type_slug,
        author,
        model,
        all_parts_objectives,
        scope \\ "embedded",
        title \\ nil,
        objective_map \\ %{},
        tags \\ [],
        learning_model_parameters \\ nil
      ) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <-
           Publishing.project_working_publication(project_slug) |> trap_nil(),
         {:ok, %{content: content} = activity} <-
           process_create_activity(
             project,
             author,
             publication,
             scope,
             activity_type_slug,
             all_parts_objectives,
             model,
             title,
             tags,
             objective_map,
             learning_model_parameters
           ) do
      case Transformers.apply_transforms([activity]) do
        [{:ok, nil}] -> {:ok, {activity, content}}
        [{:ok, transformed}] -> {:ok, {activity, transformed}}
        _ -> {:ok, {activity, nil}}
      end
    else
      error ->
        error
    end
  end

  @doc """
  Attempts to process a request to create a list of new activities.

  Returns:

  .`{:ok, list({String.t(), %Revision{}})}` when the creation processes succeeds
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to create this activity
  .`{:error, {:error}}` unknown error
  """
  @spec create_bulk(String.t(), %Author{}, %{}) ::
          {:ok, list({String.t(), %Revision{}})}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:not_authorized}}
  def create_bulk(
        project_slug,
        author,
        bulk_activity_data,
        scope \\ "embedded"
      ) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <-
           Publishing.project_working_publication(project_slug) |> trap_nil() do
      activities =
        Enum.reduce(bulk_activity_data, [], fn activity_data, m ->
          %{
            "activityTypeSlug" => activity_type_slug,
            "objectives" => objectives,
            "content" => model,
            "title" => title,
            "tags" => tags
          } = activity_data

          objective_map =
            Map.get(activity_data, "objectiveMap") || Map.get(activity_data, "objective_map") ||
              %{}

          case process_create_activity(
                 project,
                 author,
                 publication,
                 scope,
                 activity_type_slug,
                 objectives,
                 model,
                 title,
                 tags,
                 objective_map
               ) do
            {:ok, activity} ->
              m ++ [%{activity_type_slug: activity_type_slug, activity: activity}]

            _ ->
              m
          end
        end)

      {:ok, activities}
    else
      error -> error
    end
  end

  defp process_create_activity(
         project,
         author,
         publication,
         scope,
         activity_type_slug,
         objectives,
         model,
         title,
         tags,
         objective_map,
         learning_model_parameters \\ nil
       ) do
    Repo.transaction(fn ->
      with {:ok, activity_type} <-
             Activities.get_registration_by_slug(activity_type_slug) |> trap_nil(),
           {:ok, model} <- prepare_creation_model(activity_type_slug, model),
           {:ok, objectives} <- attach_objectives(model, objectives, objective_map),
           {:ok, activity} <-
             Resources.create_new(
               %{
                 title: title || activity_type.title,
                 scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("total"),
                 objectives: objectives,
                 author_id: author.id,
                 content: model,
                 scope: scope,
                 activity_type_id: activity_type.id,
                 tags: tags,
                 learning_model_parameters: learning_model_parameters
               },
               Oli.Resources.ResourceType.id_for_activity()
             ),
           {:ok, _} <-
             Course.create_project_resource(%{
               project_id: project.id,
               resource_id: activity.resource_id
             })
             |> trap_nil(),
           {:ok, _mapping} <-
             Publishing.create_published_resource(%{
               publication_id: publication.id,
               resource_id: activity.resource_id,
               revision_id: activity.id
             }) do
        activity
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  defp prepare_creation_model("oli_embedded", model) when is_map(model) do
    case should_clone_embedded_bundle?(model) do
      true ->
        case clone_embedded_bundle(model) do
          {:ok, cloned_model} ->
            {:ok, cloned_model}

          {:error, reason} ->
            Logger.warning(
              "Could not clone starter embedded bundle during activity creation, continuing with original model: #{inspect(reason)}"
            )

            {:ok, annotate_embedded_bundle_fallback(model, reason)}
        end

      false ->
        {:ok, model}
    end
  end

  defp prepare_creation_model(_activity_type_slug, model), do: {:ok, model}

  defp should_clone_embedded_bundle?(model) do
    resource_base = Map.get(model, "resourceBase")
    model_xml = Map.get(model, "modelXml", "")

    is_binary(resource_base) and not String.starts_with?(resource_base, "bundles/") and
      is_binary(model_xml) and String.contains?(model_xml, "webcontent/custom_activity/")
  end

  defp repairable_embedded_bundle?(model) do
    should_clone_embedded_bundle?(model) and fallback_embedded_bundle_status?(model)
  end

  defp fallback_embedded_bundle_status?(model) do
    case Map.get(model, "bundleStatus") do
      %{"code" => code, "message" => message} when is_binary(code) and is_binary(message) -> true
      _ -> false
    end
  end

  defp clone_embedded_bundle(model) do
    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)
    resource_base = "bundles/#{Ecto.UUID.generate()}"
    old_resource_base = Map.get(model, "resourceBase")

    with {:ok, {source_prefix, object_keys}} <- list_embedded_bundle_source_objects(bucket_name),
         :ok <-
           copy_embedded_bundle_objects(bucket_name, resource_base, source_prefix, object_keys),
         {:ok, migrated_resources} <-
           migrate_tracked_embedded_resource_urls(
             bucket_name,
             old_resource_base,
             resource_base,
             Map.get(model, "resourceURLs", [])
           ) do
      {:ok,
       model
       |> Map.delete("bundleStatus")
       |> Map.put("resourceBase", resource_base)
       |> Map.put("resourceURLs", migrated_resources.urls)
       |> Map.put(
         "modelXml",
         rewrite_tracked_embedded_resource_references(
           Map.get(model, "modelXml", ""),
           normalize_embedded_resource_base(old_resource_base),
           migrated_resources.relative_paths
         )
       )
       |> Map.put("resourceVerification", %{})}
    end
  end

  defp apply_embedded_bundle_repair_overlay({:ok, repaired_model}, client_model)
       when is_map(client_model) do
    {:ok, Map.merge(repaired_model, Map.take(client_model, @embedded_bundle_repair_overlay_keys))}
  end

  defp apply_embedded_bundle_repair_overlay(result, _client_model), do: result

  defp annotate_embedded_bundle_fallback(model, reason) when is_map(model) do
    Map.put(model, "bundleStatus", %{
      "code" => embedded_bundle_failure_code(reason),
      "message" => embedded_bundle_failure_message(reason)
    })
  end

  defp embedded_bundle_failure_code(:missing_embedded_bundle_source),
    do: "missing_starter_bundle_source"

  defp embedded_bundle_failure_code(:embedded_bundle_copy_failed),
    do: "starter_bundle_copy_failed"

  defp embedded_bundle_failure_code(:embedded_resource_migration_failed),
    do: "tracked_resource_migration_failed"

  defp embedded_bundle_failure_code(_reason), do: "bundle_clone_failed"

  defp embedded_bundle_failure_message(:missing_embedded_bundle_source),
    do:
      "Starter bundle files were not found in the media bucket. Ensure the default embedded bundle exists under media/webcontent/custom_activity/."

  defp embedded_bundle_failure_message(:embedded_bundle_copy_failed),
    do:
      "Starter bundle files were found, but copying them into a new bundle failed. Check MinIO/S3 write access and object-copy support."

  defp embedded_bundle_failure_message(:embedded_resource_migration_failed),
    do:
      "The starter bundle was cloned, but tracked uploaded files could not be migrated into the new bundle."

  defp embedded_bundle_failure_message(_reason),
    do: "The starter bundle could not be cloned during activity creation."

  defp migrate_tracked_embedded_resource_urls(
         _bucket_name,
         _old_resource_base,
         _new_resource_base,
         resource_urls
       )
       when resource_urls in [nil, []] do
    {:ok, %{urls: [], relative_paths: []}}
  end

  defp migrate_tracked_embedded_resource_urls(
         bucket_name,
         old_resource_base,
         new_resource_base,
         resource_urls
       )
       when is_list(resource_urls) do
    old_directory = normalize_embedded_resource_base(old_resource_base)
    media_url = Application.fetch_env!(:oli, :media_url)

    resource_urls
    |> parallel_embedded_bundle_map(fn url ->
      with {:ok, source_key} <- media_key_from_url(url),
           {:ok, relative_path} <- tracked_relative_path(source_key, old_directory),
           destination_key <- Path.join(["media", new_resource_base, relative_path]),
           {:ok, %{status_code: 200}} <-
             S3.put_object_copy(bucket_name, destination_key, bucket_name, source_key,
               acl: :public_read
             )
             |> Oli.HTTP.aws().request() do
        {:ok, %{url: "#{media_url}/#{destination_key}", relative_path: relative_path}}
      else
        _ ->
          {:error, :embedded_resource_migration_failed}
      end
    end)
    |> case do
      {:ok, migrated_resources} ->
        {:ok,
         %{
           urls: Enum.map(migrated_resources, & &1.url),
           relative_paths: Enum.map(migrated_resources, & &1.relative_path)
         }}

      {:error, _reason, _results} ->
        {:error, :embedded_resource_migration_failed}
    end
  end

  defp migrate_tracked_embedded_resource_urls(
         _bucket_name,
         _old_resource_base,
         _new_resource_base,
         _resource_urls
       ) do
    {:error, :embedded_resource_migration_failed}
  end

  defp normalize_embedded_resource_base(nil), do: ""

  defp normalize_embedded_resource_base(resource_base) do
    case String.trim(to_string(resource_base), "/") do
      "" -> ""
      "bundles/" <> _rest = normalized -> normalized
      normalized -> Path.join("bundles", normalized)
    end
  end

  defp media_key_from_url(url) when is_binary(url) do
    path =
      case URI.parse(url) do
        %URI{path: path} when is_binary(path) and path != "" -> path
        _ -> url
      end

    normalized = String.trim_leading(path, "/")

    cond do
      String.starts_with?(normalized, "media/") ->
        {:ok, normalized}

      String.contains?(normalized, "/media/") ->
        [_prefix, suffix] = String.split(normalized, "/media/", parts: 2)
        {:ok, "media/" <> suffix}

      true ->
        {:error, :invalid_embedded_resource_url}
    end
  end

  defp media_key_from_url(_), do: {:error, :invalid_embedded_resource_url}

  defp tracked_relative_path(source_key, old_directory) do
    prefix = "media/#{old_directory}/"

    case String.replace_prefix(source_key, prefix, "") do
      ^source_key -> {:error, :tracked_resource_outside_source_directory}
      relative_path -> {:ok, relative_path}
    end
  end

  defp rewrite_tracked_embedded_resource_references(model_xml, _old_directory, [])
       when is_binary(model_xml),
       do: model_xml

  defp rewrite_tracked_embedded_resource_references(model_xml, old_directory, relative_paths)
       when is_binary(model_xml) do
    Enum.reduce(relative_paths, model_xml, fn relative_path, xml ->
      [
        "/media/#{old_directory}/#{relative_path}",
        "media/#{old_directory}/#{relative_path}",
        "/super_media/#{old_directory}/#{relative_path}",
        "super_media/#{old_directory}/#{relative_path}",
        "/#{old_directory}/#{relative_path}",
        "#{old_directory}/#{relative_path}"
      ]
      |> Enum.reduce(xml, fn old_reference, rewritten_xml ->
        String.replace(rewritten_xml, old_reference, relative_path)
      end)
    end)
  end

  defp rewrite_tracked_embedded_resource_references(model_xml, _old_directory, _relative_paths),
    do: model_xml

  defp list_embedded_bundle_source_objects(bucket_name) do
    Enum.reduce_while(
      @embedded_bundle_source_prefixes,
      {:error, :missing_embedded_bundle_source},
      fn prefix, _acc ->
        case S3.list_objects(bucket_name, prefix: prefix)
             |> Oli.HTTP.aws().request() do
          {:ok, %{status_code: 200, body: %{contents: contents}}} when is_list(contents) ->
            object_keys =
              contents
              |> Enum.map(&Map.get(&1, :key))
              |> Enum.filter(&is_binary/1)

            case object_keys do
              [] -> {:cont, {:error, :missing_embedded_bundle_source}}
              keys -> {:halt, {:ok, {prefix, keys}}}
            end

          _ ->
            {:cont, {:error, :missing_embedded_bundle_source}}
        end
      end
    )
  end

  defp copy_embedded_bundle_objects(bucket_name, resource_base, source_prefix, object_keys) do
    destination_prefix = "media/#{resource_base}/"

    object_keys
    |> parallel_embedded_bundle_map(fn source_key ->
      destination_key =
        case source_prefix do
          "media/" <> _rest -> String.replace_prefix(source_key, "media/", destination_prefix)
          _ -> destination_prefix <> source_key
        end

      case S3.put_object_copy(bucket_name, destination_key, bucket_name, source_key,
             acl: :public_read
           )
           |> Oli.HTTP.aws().request() do
        {:ok, %{status_code: 200}} -> {:ok, destination_key}
        _ -> {:error, :embedded_bundle_copy_failed}
      end
    end)
    |> case do
      {:ok, _copied_keys} -> :ok
      {:error, _reason, _results} -> {:error, :embedded_bundle_copy_failed}
    end
  end

  defp embedded_bundle_s3_concurrency do
    config = Application.get_env(:oli, __MODULE__, [])
    Keyword.get(config, :embedded_bundle_s3_concurrency, @default_embedded_bundle_s3_concurrency)
  end

  defp embedded_bundle_s3_timeout_ms do
    config = Application.get_env(:oli, __MODULE__, [])
    Keyword.get(config, :embedded_bundle_s3_timeout_ms, @default_embedded_bundle_s3_timeout_ms)
  end

  defp parallel_embedded_bundle_map(items, mapper) do
    items
    |> Task.async_stream(
      mapper,
      max_concurrency: embedded_bundle_s3_concurrency(),
      ordered: true,
      timeout: embedded_bundle_s3_timeout_ms(),
      on_timeout: :kill_task
    )
    |> Enum.reduce({[], nil}, fn
      {:ok, {:ok, value}}, {results, error} ->
        {[value | results], error}

      {:ok, {:error, reason}}, {results, nil} ->
        {results, reason}

      {:ok, {:error, _reason}}, {results, error} ->
        {results, error}

      {:exit, :timeout}, {results, nil} ->
        {results, :embedded_bundle_s3_timeout}

      {:exit, :timeout}, {results, error} ->
        {results, error}

      {:exit, _reason}, {results, nil} ->
        {results, :embedded_bundle_s3_failed}

      {:exit, _reason}, {results, error} ->
        {results, error}
    end)
    |> case do
      {results, nil} -> {:ok, Enum.reverse(results)}
      {results, error} -> {:error, error, Enum.reverse(results)}
    end
  end

  @spec create_context(any, any, any, any) ::
          {:error, :not_found}
          | {:ok,
             %Oli.Authoring.Editing.ActivityContext{
               activityId: any,
               activitySlug: binary,
               allObjectives: list,
               authorEmail: any,
               authoringElement: any,
               authoringScript: any,
               description: any,
               friendlyName: any,
               loWellFormed: boolean,
               model: any,
               objectives: any,
               projectSlug: any,
               resourceId: any,
               resourceSlug: binary,
               resourceTitle: any,
               title: any
             }}
  @doc """
  Creates the context necessary to power a client side activity editor,
  where this activity is being editing within the context of being
  referenced from a resource.
  """
  def create_context(project_slug, revision_slug, activity_slug, author) do
    with {:ok, publication} <-
           Publishing.project_working_publication(project_slug) |> trap_nil(),
         publication = Repo.preload(publication, :project),
         {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil(),
         {:ok, lo_well_formed} <-
           ProjectClassifier.ensure_classified(publication.project, publication),
         {:ok, all_objectives} <-
           Publishing.get_published_objective_details(publication.id) |> trap_nil(),
         {:ok, %{title: resource_title}} <-
           PageEditor.get_latest_revision(publication, resource) |> trap_nil(),
         {:ok, %{id: activity_id}} <-
           Resources.get_resource_from_slug(activity_slug) |> trap_nil(),
         {:ok,
          %{
            activity_type: activity_type,
            title: title,
            objectives: objectives,
            tags: tags
          } = revision} <-
           get_latest_revision(publication.id, activity_id) |> trap_nil(),
         {:ok, %{content: model}} <- maybe_migrate_revision_content(revision) do
      all_objectives_with_parents = PageEditor.construct_parent_references(all_objectives)
      filtered_objectives = filter_objectives_to_existing(objectives, all_objectives_with_parents)

      context = %ActivityContext{
        authoringScript: activity_type.authoring_script,
        authoringElement: activity_type.authoring_element,
        friendlyName: activity_type.title,
        description: activity_type.description,
        authorEmail: author.email,
        projectSlug: project_slug,
        resourceId: resource.id,
        resourceSlug: revision_slug,
        resourceTitle: resource_title,
        activityId: activity_id,
        activitySlug: activity_slug,
        title: title,
        model: model,
        objectives: filtered_objectives,
        allObjectives: all_objectives_with_parents,
        loWellFormed: lo_well_formed,
        typeSlug: activity_type.slug,
        tags: tags,
        variables:
          Oli.Delivery.Page.ActivityContext.build_variables_map(
            activity_type.variables,
            activity_type.petite_label
          )
      }

      {:ok, context}
    else
      _ -> {:error, :not_found}
    end
  end

  def create_contexts(
        all_objectives_with_parents,
        project_slug,
        activity_ids,
        lo_well_formed
      ) do
    type_by_id =
      Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn t, m -> Map.put(m, t.id, t) end)

    AuthoringResolver.from_resource_id(project_slug, activity_ids)
    |> Enum.filter(fn r -> !is_nil(r) end)
    |> Enum.map(fn r ->
      activity_type = Map.get(type_by_id, r.activity_type_id)

      {:ok, r} = maybe_migrate_revision_content(r)

      filtered_objectives =
        filter_objectives_to_existing(r.objectives, all_objectives_with_parents)

      %ActivityContext{
        authoringScript: activity_type.authoring_script,
        authoringElement: activity_type.authoring_element,
        friendlyName: activity_type.title,
        description: activity_type.description,
        activityId: r.resource_id,
        activitySlug: r.slug,
        title: r.title,
        model: r.content,
        objectives: filtered_objectives,
        allObjectives: all_objectives_with_parents,
        loWellFormed: lo_well_formed,
        typeSlug: activity_type.slug,
        tags: r.tags,
        variables:
          Oli.Delivery.Page.ActivityContext.build_variables_map(
            activity_type.variables,
            activity_type.petite_label
          )
      }
    end)
  end

  # Retrieve the latest (current) revision for a resource given the
  # active publication
  def get_latest_revision(publication_id, resource_id) do
    Publishing.get_published_revision(publication_id, resource_id)
    |> Repo.preload([:activity_type])
  end

  defp maybe_migrate_revision_content(%Revision{content: content} = revision) do
    {:ok, %Revision{revision | content: ContentMigrator.migrate(content, :activity, to: :latest)}}
  end
end
