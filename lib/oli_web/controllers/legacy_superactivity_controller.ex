defmodule OliWeb.LegacySuperactivityController do
  use OliWeb, :controller
  require Logger

  alias XmlBuilder

  alias Oli.Interop.CustomActivities.{
    SuperActivityClient,
    SuperActivitySession,
    AttemptHistory,
    FileRecord,
    FileDirectory,
    PreviewSessions,
    Package
  }

  alias Oli.Accounts.{Author, User}
  alias Oli.Authoring.Course
  alias Oli.Activities
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Delivery.Attempts.ActivityLifecycle.ApplyClientEvaluation
  alias Oli.Delivery.Attempts.Core.ClientEvaluation
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Activities.Model.Feedback
  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo
  alias Lti_1p3.Roles.ContextRoles

  @default_preview_max_file_bytes 1_000_000
  @preview_file_storage_prefix "preview-save-files"

  defmodule LegacySuperactivityContext do
    @moduledoc false
    defstruct [
      :server_time_zone,
      :user,
      :host,
      :section,
      :datashop_session_id,
      :activity_attempt,
      :resource_attempt,
      :resource_access,
      :attempt_user_id,
      :save_files,
      :instructors,
      :enrollment,
      :web_content_url,
      :host_url,
      :base,
      :src
    ]
  end

  def context(conn, %{"attempt_guid" => attempt_guid} = _params) do
    case fetch_context(conn, attempt_guid) do
      {:ok, context} ->
        json(conn, context_response(conn.host, context))

      {:error, :not_found} ->
        error(conn, 404, "Attempt not found")

      {:error, _reason} ->
        error(conn, 500, "Unable to create preview context")
    end
  end

  def preview_context(
        conn,
        %{"attemptGuid" => attempt_guid, "model" => model, "context" => activity_context}
      ) do
    case init_preview_session(conn, attempt_guid, model, activity_context) do
      {:ok, context} ->
        json(conn, context_response(conn.host, context))

      {:error, :unauthorized} ->
        error(conn, 403, "Unauthorized")

      {:error, reason} ->
        Logger.error("Could not create embedded preview session: #{inspect(reason)}")
        error(conn, 400, "Unable to create preview context")
    end
  end

  def process(
        conn,
        %{"commandName" => command_name, "activityContextGuid" => attempt_guid} = params
      ) do
    with {:ok, context} <- fetch_context(conn, attempt_guid),
         xml_response <- process_command(command_name, context, params) do
      case xml_response do
        {:ok, xml} ->
          conn
          |> put_resp_content_type("text/xml")
          |> send_resp(200, xml)

        {:error, error, code} ->
          conn
          |> put_resp_content_type("text/text")
          |> send_resp(code, error)
      end
    else
      {:error, :not_found} ->
        conn
        |> put_resp_content_type("text/text")
        |> send_resp(404, "Attempt not found")

      {:error, :unauthorized} ->
        conn
        |> put_resp_content_type("text/text")
        |> send_resp(403, "Unauthorized")

      {:error, reason} ->
        Logger.error("Could not process legacy superactivity command: #{inspect(reason)}")

        conn
        |> put_resp_content_type("text/text")
        |> send_resp(500, "server error")
    end
  end

  def create_media(conn, %{"directory" => directory, "file" => file, "name" => name}) do
    case Base.decode64(file) do
      {:ok, contents} ->
        bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)
        hash = :crypto.hash(:md5, contents) |> Base.encode16()
        directory = normalize_media_directory(directory)
        upload_path = Path.join(["/media", directory, "webcontent", hash, name])
        media_url = Application.fetch_env!(:oli, :media_url)

        case upload_file(bucket_name, upload_path, contents) do
          {:ok, %{status_code: 200}} ->
            json(conn, %{
              type: "success",
              url: "#{media_url}#{upload_path}"
            })

          _ ->
            error(conn, 400, "failed to add superactivity media")
        end

      _ ->
        error(conn, 400, "invalid encoded file")
    end
  end

  def verify_media(
        conn,
        %{"projectSlug" => project_slug, "activityId" => activity_id, "references" => references}
      )
      when is_list(references) do
    with {:ok, resource_base} <- resolve_authorized_resource_base(conn, project_slug, activity_id),
         {:ok, resolved_references} <-
           resolve_verified_media_references(references, resource_base) do
      bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

      existing_keys =
        resolved_references
        |> Enum.map(&elem(&1, 1))
        |> Enum.group_by(&media_lookup_prefix/1)
        |> Enum.reduce_while({:ok, MapSet.new()}, fn {prefix, keys}, {:ok, acc} ->
          case list_media_keys(bucket_name, prefix) do
            {:ok, listed_keys} ->
              keys_set = MapSet.new(keys)

              existing_keys =
                listed_keys
                |> Enum.filter(&MapSet.member?(keys_set, &1))
                |> Enum.reduce(acc, &MapSet.put(&2, &1))

              {:cont, {:ok, existing_keys}}

            {:error, reason} ->
              {:halt, {:error, {:media_lookup_failed, prefix, reason}}}
          end
        end)

      case existing_keys do
        {:ok, existing_keys} ->
          statuses =
            resolved_references
            |> Enum.map(fn {reference, resolved_key} ->
              {reference,
               if(MapSet.member?(existing_keys, resolved_key), do: "verified", else: "missing")}
            end)
            |> Enum.into(%{})

          json(conn, %{statuses: statuses})

        {:error, {:media_lookup_failed, _prefix, reason}} ->
          Logger.error("Could not verify embedded activity media: #{inspect(reason)}")
          error(conn, 500, "Unable to verify supporting files")
      end
    else
      {:error, :not_authorized} ->
        error(conn, 403, "Unauthorized")

      {:error, :not_found} ->
        error(conn, 404, "Activity not found")

      {:error, {:invalid_request, message}} ->
        error(conn, 400, message)

      {:error, _reason} ->
        error(conn, 400, "invalid verification request")
    end
  end

  def verify_media(conn, _params), do: error(conn, 400, "invalid verification request")

  def export_package(
        conn,
        %{"model" => model, "projectSlug" => project_slug, "activityId" => activity_id}
      )
      when is_map(model) do
    with {:ok, resource_base} <- resolve_authorized_resource_base(conn, project_slug, activity_id),
         {:ok, zip_binary} <- Package.export(model, resource_base) do
      send_download(conn, {:binary, zip_binary}, filename: "embedded_activity_package.zip")
    else
      {:error, :not_authorized} ->
        error(conn, 403, "Unauthorized")

      {:error, :not_found} ->
        error(conn, 404, "Activity not found")

      {:error, :missing_resource_base} ->
        error(conn, 400, "Embedded activity bundle is missing")

      {:error, {:invalid_request, message}} ->
        error(conn, 400, message)

      {:error, reason} ->
        Logger.error("Could not export embedded activity package: #{inspect(reason)}")
        error(conn, 400, "Unable to export embedded activity package")
    end
  end

  def export_package(conn, _params), do: error(conn, 400, "invalid embedded activity export")

  def import_package(
        conn,
        %{
          "upload" => %Plug.Upload{path: path},
          "projectSlug" => project_slug,
          "activityId" => activity_id
        }
      ) do
    with {:ok, resource_base} <- resolve_authorized_resource_base(conn, project_slug, activity_id),
         {:ok, model} <- Package.import(path, resource_base) do
      json(conn, %{type: "success", model: model})
    else
      {:error, reason} ->
        Logger.error("Could not import embedded activity package: #{inspect(reason)}")
        import_error(conn, reason)
    end
  end

  def import_package(conn, _params),
    do: import_error(conn, {:invalid_request, "invalid embedded activity package"})

  defp resolve_authorized_resource_base(conn, project_slug, activity_id) do
    with %Author{} = author <- conn.assigns[:current_author],
         %{} = project <- Course.get_project_by_slug(project_slug),
         true <- Oli.Accounts.can_access?(author, project),
         {:ok, parsed_activity_id} <- parse_activity_id(activity_id),
         revision when not is_nil(revision) <-
           AuthoringResolver.from_resource_id(project_slug, parsed_activity_id) do
      {:ok,
       case revision.content["resourceBase"] do
         value when is_binary(value) ->
           if String.starts_with?(value, "bundles/"), do: value, else: nil

         _ ->
           nil
       end}
    else
      nil -> {:error, :not_found}
      false -> {:error, :not_authorized}
      {:error, _reason} = error -> error
      _ -> {:error, :not_found}
    end
  end

  defp parse_activity_id(value) when is_integer(value), do: {:ok, value}

  defp parse_activity_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> {:ok, parsed}
      _ -> {:error, {:invalid_request, "invalid activity id"}}
    end
  end

  defp parse_activity_id(_), do: {:error, {:invalid_request, "invalid activity id"}}

  defp resolve_verified_media_references(references, resource_base) do
    references
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, []}, fn reference, {:ok, acc} ->
      case Package.resolve_bundle_media_reference(reference, resource_base) do
        {:ok, %{key: key}} ->
          {:cont, {:ok, [{reference, key} | acc]}}

        {:error, _reason} ->
          {:halt, {:error, {:invalid_request, "invalid verification request"}}}
      end
    end)
    |> case do
      {:ok, resolved_references} -> {:ok, Enum.reverse(resolved_references)}
      error -> error
    end
  end

  defp upload_file(bucket, file_name, contents) do
    mime_type = MIME.from_path(file_name)

    options = [
      {:acl, :public_read},
      {:content_type, mime_type},
      {:cache_control, "no-cache, no-store, must-revalidate"}
    ]

    ExAws.S3.put_object(bucket, file_name, contents, options) |> aws_client().request()
  end

  defp list_media_keys(bucket_name, prefix) do
    case ExAws.S3.list_objects(bucket_name, prefix: prefix) |> aws_client().request() do
      {:ok, %{status_code: 200, body: %{contents: contents}}} ->
        {:ok,
         contents
         |> Enum.map(fn content -> Map.get(content, :key) || Map.get(content, "Key") end)
         |> Enum.filter(&is_binary/1)}

      error ->
        error
    end
  end

  defp media_lookup_prefix(key) do
    key
    |> Path.dirname()
    |> Kernel.<>("/")
  end

  defp normalize_directory(nil), do: ""
  defp normalize_directory(directory), do: String.trim(directory, "/")

  defp normalize_media_directory(directory) do
    case normalize_directory(directory) do
      "" -> ""
      "bundles/" <> _rest = normalized -> normalized
      normalized -> Path.join("bundles", normalized)
    end
  end

  defp preview_max_file_bytes do
    config = Application.get_env(:oli, __MODULE__, [])
    Keyword.get(config, :preview_max_file_bytes, @default_preview_max_file_bytes)
  end

  defp preview_storage_key(attempt_guid, attempt_number, file_name) do
    encoded_file_name = Base.url_encode64(to_string(file_name), padding: false)

    Path.join([
      @preview_file_storage_prefix,
      to_string(attempt_guid),
      to_string(attempt_number),
      encoded_file_name
    ])
  end

  defp put_preview_file_object(bucket_name, storage_key, contents, mime_type) do
    options =
      case mime_type do
        value when is_binary(value) and value != "" -> [content_type: value]
        _ -> []
      end

    ExAws.S3.put_object(bucket_name, storage_key, contents, options) |> aws_client().request()
  end

  defp get_preview_file_object(bucket_name, storage_key) do
    ExAws.S3.get_object(bucket_name, storage_key) |> aws_client().request()
  end

  defp delete_preview_file_object(bucket_name, storage_key) do
    ExAws.S3.delete_object(bucket_name, storage_key) |> aws_client().request()
  end

  defp aws_client(), do: Application.get_env(:oli, :aws_client, ExAws)

  def file_not_found(conn, _params) do
    conn
    |> put_status(404)
    |> text("File Not Found")
  end

  defp fetch_context(conn, attempt_guid) do
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

    case Attempts.get_activity_attempt_by(attempt_guid: attempt_guid) do
      nil ->
        fetch_preview_context(conn, attempt_guid)

      activity_attempt ->
        {:ok,
         fetch_delivery_context(
           conn.host,
           conn.assigns.current_user,
           activity_attempt,
           datashop_session_id
         )}
    end
  end

  defp fetch_delivery_context(host, user, activity_attempt, datashop_session_id)
       when is_map(activity_attempt) do
    activity_attempt =
      Repo.preload(activity_attempt, [:part_attempts, revision: [:scoring_strategy]])

    %{"base" => base, "src" => src, "resourceBase" => resource_base} =
      activity_attempt.revision.content

    resource_attempt = Attempts.get_resource_attempt_by(id: activity_attempt.resource_attempt_id)

    resource_access = Attempts.get_resource_access(resource_attempt.resource_access_id)

    # different than current user when instructor reviews student attempt
    attempt_user_id = resource_access.user_id

    section =
      Sections.get_section_preloaded!(resource_access.section_id)
      |> Repo.preload([:institution, :section_project_publications])

    instructors = Sections.fetch_instructors(section.slug)

    enrollment =
      Sections.get_enrollment(section.slug, user.id)
      |> Repo.preload([:context_roles])

    save_files =
      ActivityLifecycle.get_activity_attempt_save_files(
        activity_attempt.attempt_guid,
        Integer.to_string(attempt_user_id),
        activity_attempt.attempt_number
      )

    %LegacySuperactivityContext{
      server_time_zone: get_timezone(),
      user: user,
      host: host,
      section: section,
      datashop_session_id: datashop_session_id,
      activity_attempt: activity_attempt,
      resource_attempt: resource_attempt,
      resource_access: resource_access,
      attempt_user_id: attempt_user_id,
      save_files: save_files,
      instructors: instructors,
      enrollment: enrollment,
      web_content_url: web_content_url(host, resource_base),
      host_url: "https://#{host}",
      base: base,
      src: src
    }
  end

  defp fetch_delivery_context(host, user, attempt_guid, datashop_session_id)
       when is_binary(attempt_guid) do
    activity_attempt = Attempts.get_activity_attempt_by(attempt_guid: attempt_guid)
    fetch_delivery_context(host, user, activity_attempt, datashop_session_id)
  end

  defp init_preview_session(conn, attempt_guid, model, activity_context) do
    with {:ok, preview_user} <- preview_user(conn),
         {:ok, activity_type} <- preview_activity_type(),
         session <-
           build_preview_session(
             attempt_guid,
             preview_user,
             model,
             activity_context,
             activity_type
           ),
         {:ok, _session} <- PreviewSessions.put(attempt_guid, session) do
      {:ok,
       preview_session_to_context(
         conn.host,
         session,
         Plug.Conn.get_session(conn, :datashop_session_id)
       )}
    end
  end

  defp fetch_preview_context(conn, attempt_guid) do
    with {:ok, session} <- PreviewSessions.get(attempt_guid),
         :ok <- authorize_preview_session(conn, session) do
      {:ok,
       preview_session_to_context(
         conn.host,
         session,
         Plug.Conn.get_session(conn, :datashop_session_id)
       )}
    end
  end

  defp preview_activity_type() do
    case Activities.get_registration_by_slug("oli_embedded") do
      nil -> {:error, :missing_activity_type}
      activity_type -> {:ok, activity_type}
    end
  end

  defp preview_user(%Plug.Conn{assigns: %{current_user: %User{} = user}}), do: {:ok, user}

  defp preview_user(%Plug.Conn{assigns: %{current_author: %Author{} = author}}) do
    {:ok,
     %{
       id: "author:#{author.id}",
       guest: false,
       locale: "en",
       inserted_at: author.inserted_at || DateTime.utc_now(),
       email: author.email,
       given_name: author.given_name || author.name || "Author",
       family_name: author.family_name || ""
     }}
  end

  defp preview_user(_conn), do: {:error, :unauthorized}

  defp authorize_preview_session(conn, session) do
    current_user_id = conn.assigns[:current_user] && to_string(conn.assigns.current_user.id)
    current_author_id = conn.assigns[:current_author] && to_string(conn.assigns.current_author.id)

    cond do
      session.actor_user_id != nil and session.actor_user_id == current_user_id ->
        :ok

      session.actor_author_id != nil and session.actor_author_id == current_author_id ->
        :ok

      true ->
        {:error, :unauthorized}
    end
  end

  defp build_preview_session(attempt_guid, preview_user, model, activity_context, activity_type) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    part_ids = preview_part_ids(model)

    slug =
      Map.get(activity_context, "sectionSlug") || Map.get(activity_context, "projectSlug") ||
        "preview"

    section_title =
      Map.get(activity_context, "pageTitle") || Map.get(model, "title") || "Embedded Preview"

    max_attempts = preview_max_attempts(activity_context)
    revision_title = Map.get(model, "title") || "Embedded activity"
    scoring_strategy = %{type: preview_scoring_strategy(activity_context, model)}

    activity_attempt =
      %{
        attempt_guid: attempt_guid,
        attempt_number: 1,
        resource_id: Map.get(activity_context, "resourceId", 0),
        date_evaluated: nil,
        date_submitted: nil,
        score: nil,
        out_of: nil,
        custom_scores: %{},
        inserted_at: now,
        updated_at: now,
        revision: %{
          title: revision_title,
          inserted_at: now,
          graded: Map.get(activity_context, "graded", false),
          max_attempts: max_attempts,
          scoring_strategy: scoring_strategy,
          activity_type: %{
            slug: activity_type.slug,
            title: activity_type.title
          },
          content: model
        },
        part_attempts: build_preview_part_attempts(attempt_guid, part_ids, now)
      }

    %{
      actor_user_id: if(match?(%User{}, preview_user), do: to_string(preview_user.id), else: nil),
      actor_author_id:
        if(match?(%User{}, preview_user),
          do: nil,
          else: preview_user.id |> to_string() |> String.replace_prefix("author:", "")
        ),
      user: preview_user,
      section: %{
        id: "preview-section:#{slug}",
        slug: slug,
        title: section_title,
        inserted_at: now,
        updated_at: now,
        start_date: nil,
        end_date: nil,
        open_and_free: true,
        registration_open: true,
        institution: nil
      },
      resource_access: %{
        id: "preview-resource-access:#{attempt_guid}",
        user_id: preview_user.id,
        preview: true
      },
      enrollment: %{
        id: "preview-enrollment:#{attempt_guid}",
        inserted_at: now,
        context_roles: [ContextRoles.get_role(:context_instructor)]
      },
      instructors: [preview_user],
      activity_attempt: activity_attempt,
      resource_attempt: %{
        inserted_at: now,
        updated_at: now,
        revision: %{max_attempts: max_attempts},
        activity_attempts: [activity_attempt]
      },
      file_records: %{}
    }
  end

  defp preview_session_to_context(host, session, datashop_session_id) do
    %{"base" => base, "src" => src, "resourceBase" => resource_base} =
      session.activity_attempt.revision.content

    %LegacySuperactivityContext{
      server_time_zone: get_timezone(),
      user: session.user,
      host: host,
      section: session.section,
      datashop_session_id: datashop_session_id,
      activity_attempt: session.activity_attempt,
      resource_attempt: session.resource_attempt,
      resource_access: session.resource_access,
      attempt_user_id: session.user.id,
      save_files: preview_save_files(session),
      instructors: session.instructors,
      enrollment: session.enrollment,
      web_content_url: web_content_url(host, resource_base),
      host_url: "https://#{host}",
      base: base,
      src: src
    }
  end

  defp context_response(host, %LegacySuperactivityContext{} = context) do
    %{
      attempt_guid: context.activity_attempt.attempt_guid,
      src_url: "https://#{host}/superactivity/#{context.base}/#{context.src}",
      activity_type: context.activity_attempt.revision.activity_type.slug,
      server_url: "https://#{host}/jcourse/superactivity/server",
      user_guid: context.user.id,
      mode: "delivery",
      part_ids: Enum.map(context.activity_attempt.part_attempts, & &1.part_id)
    }
  end

  defp preview_part_ids(%{"authoring" => %{"parts" => parts}}) when is_list(parts) do
    parts
    |> Enum.map(&Map.get(&1, "id"))
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> ["preview-part"]
      part_ids -> part_ids
    end
  end

  defp preview_part_ids(_model), do: ["preview-part"]

  defp build_preview_part_attempts(attempt_guid, part_ids, now) do
    Enum.map(part_ids, fn part_id ->
      %{
        part_id: part_id,
        attempt_guid: "#{attempt_guid}:#{part_id}",
        attempt_number: 1,
        score: nil,
        out_of: nil,
        inserted_at: now,
        updated_at: now,
        date_evaluated: nil
      }
    end)
  end

  defp preview_save_files(session) do
    current_attempt_number = to_string(session.activity_attempt.attempt_number)

    session.file_records
    |> Map.values()
    |> Enum.filter(&(to_string(&1.attempt_number) == current_attempt_number))
  end

  defp preview_max_attempts(activity_context) do
    case Map.get(activity_context, "maxAttempts") do
      value when is_integer(value) ->
        value

      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, _} -> parsed
          _ -> 1
        end

      _ ->
        1
    end
  end

  defp preview_scoring_strategy(activity_context, model) do
    strategy =
      Map.get(activity_context, "scoringStrategy") || Map.get(model, "scoringStrategy") ||
        "total"

    case strategy do
      value when value in ["average", "best", "most_recent", "total"] -> value
      _ -> "total"
    end
  end

  defp preview_context?(%LegacySuperactivityContext{} = context) do
    Map.get(context.resource_access, :preview, false)
  end

  defp web_content_url(host, resource_base) do
    path =
      if String.starts_with?(resource_base, "bundles/") do
        "super_media/#{resource_base}"
      else
        "super_media"
      end

    "https://#{host}/#{path}/"
  end

  defp process_command("loadClientConfig", %LegacySuperactivityContext{} = context, _params) do
    xml =
      SuperActivityClient.setup(%{
        context: context
      })
      |> XmlBuilder.document()
      |> XmlBuilder.generate()

    {:ok, xml}
  end

  defp process_command("beginSession", %LegacySuperactivityContext{} = context, _params) do
    xml =
      SuperActivitySession.setup(%{
        context: context
      })
      |> XmlBuilder.document()
      |> XmlBuilder.generate()

    {:ok, xml}
  end

  defp process_command("loadContentFile", %LegacySuperactivityContext{} = context, _params) do
    %{"modelXml" => modelXml} = context.activity_attempt.revision.content
    {:ok, modelXml}
  end

  defp process_command("startAttempt", %LegacySuperactivityContext{} = context, params) do
    if preview_context?(context) do
      preview_start_attempt(context, params)
    else
      case context.activity_attempt.date_evaluated do
        nil ->
          attempt_history(context)

        _ ->
          seed_state_from_previous = Map.get(params, "seedResponsesWithPrevious", false)

          case ActivityLifecycle.reset_activity(
                 context.section.slug,
                 context.activity_attempt.attempt_guid,
                 context.datashop_session_id,
                 seed_state_from_previous
               ) do
            {:ok, {attempt_state, _model}} ->
              attempt_history(
                fetch_delivery_context(
                  context.host,
                  context.user,
                  attempt_state.attemptGuid,
                  context.datashop_session_id
                )
              )

            {:error, _} ->
              {:error, "server error", 500}
          end
      end
    end
  end

  defp process_command(
         "scoreAttempt",
         %LegacySuperactivityContext{} = context,
         %{"scoreValue" => score_value, "scoreId" => score_type} = params
       ) do
    part_attempt =
      case Map.get(params, "partId") do
        nil ->
          # Assumes custom has a single part if partId is absent from request parameters
          Enum.at(context.activity_attempt.part_attempts, 0)

        part_id ->
          Enum.filter(context.activity_attempt.part_attempts, fn p -> part_id === p.part_id end)
      end

    # oli legacy allows for custom activities to supply arbitrary score types.
    # Worse still; an activity can supply multiple score types as part of the grade. How to handle these on Torus?
    case purse_score(score_type, score_value) do
      {:non_numeric, score_value} ->
        if preview_context?(context) do
          preview_store_non_numeric_score(context, score_type, score_value)
        else
          custom_scores =
            case context.activity_attempt.custom_scores do
              nil ->
                %{score_type => score_value}

              custom_scores ->
                Map.merge(custom_scores, %{score_type => score_value})
            end

          case Attempts.update_activity_attempt(context.activity_attempt, %{
                 custom_scores: custom_scores
               }) do
            {:ok, _} ->
              attempt_history(
                fetch_delivery_context(
                  context.host,
                  context.user,
                  context.activity_attempt.attempt_guid,
                  context.datashop_session_id
                )
              )

            {:error, message} ->
              Logger.error("Error when processing help message #{inspect(message)}")
              {:error, "server error", 500}
          end
        end

      {:numeric, score, out_of} ->
        if preview_context?(context) do
          preview_eval_numeric_score(context, score, out_of, part_attempt)
        else
          eval_numeric_score(context, score, out_of, part_attempt)
        end
    end
  end

  defp process_command("endAttempt", %LegacySuperactivityContext{} = context, _params) do
    if preview_context?(context) do
      preview_end_attempt(context)
    else
      case finalize_activity_attempt(context) do
        {:ok, _} ->
          attempt_history(
            fetch_delivery_context(
              context.host,
              context.user,
              context.activity_attempt.attempt_guid,
              context.datashop_session_id
            )
          )

        {:error, message} ->
          Logger.error("Error when processing help message #{inspect(message)}")
          {:error, "server error", 500}
      end
    end
  end

  defp process_command(command_name, %LegacySuperactivityContext{} = _context, _params)
       when command_name === "loadUserSyllabus" do
    {:error, "command not supported", 400}
  end

  defp process_command(
         "writeFileRecord",
         %LegacySuperactivityContext{} = context,
         %{
           "activityContextGuid" => attempt_guid,
           "byteEncoding" => byte_encoding,
           "fileName" => file_name,
           "fileRecordData" => content,
           "resourceTypeID" => activity_type,
           "mimeType" => mime_type,
           "userGuid" => user_id
         } = params
       ) do
    if preview_context?(context) do
      preview_write_file_record(
        context,
        attempt_guid,
        user_id,
        file_name,
        content,
        mime_type,
        byte_encoding,
        activity_type,
        Map.get(params, "attemptNumber")
      )
    else
      {:ok, save_file} =
        case context.activity_attempt.date_evaluated do
          nil ->
            file_info = %{
              attempt_guid: attempt_guid,
              user_id: user_id,
              content: content,
              mime_type: mime_type,
              byte_encoding: byte_encoding,
              activity_type: activity_type,
              file_name: file_name
            }

            attempt_number = Map.get(params, "attemptNumber")

            file_info =
              if attempt_number != nil do
                Map.merge(file_info, %{attempt_number: attempt_number})
              else
                file_info
              end

            ActivityLifecycle.save_activity_attempt_state_file(file_info)

          _ ->
            attempt_number = Map.get(params, "attemptNumber")

            save_file =
              ActivityLifecycle.get_activity_attempt_save_file(
                attempt_guid,
                user_id,
                attempt_number,
                file_name
              )

            {:ok, save_file}
        end

      case save_file do
        nil ->
          {:error, "file not found", 404}

        _ ->
          xml =
            FileRecord.setup(%{
              context: context,
              date_created: DateTime.to_unix(save_file.inserted_at),
              file_name: save_file.file_name,
              guid: save_file.file_guid
            })
            |> XmlBuilder.document()
            |> XmlBuilder.generate()

          {:ok, xml}
      end
    end
  end

  defp process_command(
         "loadFileRecord",
         %LegacySuperactivityContext{} = context,
         %{
           "activityContextGuid" => attempt_guid
         } = params
       ) do
    file_name = Map.get(params, "fileName")
    attempt_number = Map.get(params, "attemptNumber")

    if preview_context?(context) do
      preview_load_file_record(context, attempt_guid, attempt_number, file_name)
    else
      # use attempt_user from context to allow for instructor review of student work
      attempt_user_id = context.attempt_user_id

      save_file =
        ActivityLifecycle.get_activity_attempt_save_file(
          attempt_guid,
          Integer.to_string(attempt_user_id),
          attempt_number,
          file_name
        )

      case save_file do
        nil -> {:error, "file not found", 404}
        _ -> {:ok, URI.decode(save_file.content)}
      end
    end
  end

  defp process_command("deleteFileRecord", %LegacySuperactivityContext{} = context, _params) do
    if preview_context?(context) do
      preview_file_directory(context)
    else
      # no op
      xml =
        FileDirectory.setup(%{
          context: context
        })
        |> XmlBuilder.document()
        |> XmlBuilder.generate()

      {:ok, xml}
    end
  end

  defp process_command(_command_name, %LegacySuperactivityContext{} = _context, _params) do
    {:error, "command not supported", 400}
  end

  defp preview_start_attempt(%LegacySuperactivityContext{} = context, _params) do
    case context.activity_attempt.date_evaluated do
      nil ->
        attempt_history(context)

      _ ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        case PreviewSessions.update(context.activity_attempt.attempt_guid, fn session ->
               next_attempt_number = session.activity_attempt.attempt_number + 1

               next_activity_attempt =
                 session.activity_attempt
                 |> Map.merge(%{
                   attempt_number: next_attempt_number,
                   date_evaluated: nil,
                   date_submitted: nil,
                   score: nil,
                   out_of: nil,
                   custom_scores: %{},
                   inserted_at: now,
                   updated_at: now,
                   part_attempts:
                     Enum.map(session.activity_attempt.part_attempts, fn part_attempt ->
                       Map.merge(part_attempt, %{
                         attempt_number: next_attempt_number,
                         score: nil,
                         out_of: nil,
                         date_evaluated: nil,
                         inserted_at: now,
                         updated_at: now
                       })
                     end)
                 })

               session
               |> Map.put(:activity_attempt, next_activity_attempt)
               |> Map.update!(:resource_attempt, fn resource_attempt ->
                 resource_attempt
                 |> Map.put(:updated_at, now)
                 |> Map.put(
                   :activity_attempts,
                   replace_or_append_activity_attempt(
                     resource_attempt.activity_attempts,
                     next_activity_attempt
                   )
                 )
               end)
             end) do
          {:ok, updated_session} ->
            attempt_history(
              preview_session_to_context(
                context.host,
                updated_session,
                context.datashop_session_id
              )
            )

          _ ->
            {:error, "server error", 500}
        end
    end
  end

  defp preview_store_non_numeric_score(
         %LegacySuperactivityContext{} = context,
         score_type,
         score_value
       ) do
    case PreviewSessions.update(context.activity_attempt.attempt_guid, fn session ->
           custom_scores =
             Map.merge(session.activity_attempt.custom_scores || %{}, %{score_type => score_value})

           update_preview_activity_attempt(session, fn activity_attempt ->
             Map.put(activity_attempt, :custom_scores, custom_scores)
           end)
         end) do
      {:ok, updated_session} ->
        attempt_history(
          preview_session_to_context(context.host, updated_session, context.datashop_session_id)
        )

      _ ->
        {:error, "server error", 500}
    end
  end

  defp preview_end_attempt(%LegacySuperactivityContext{} = context) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case PreviewSessions.update(context.activity_attempt.attempt_guid, fn session ->
           session
           |> update_preview_activity_attempt(fn activity_attempt ->
             Map.merge(activity_attempt, %{
               date_evaluated: now,
               date_submitted: activity_attempt.date_submitted || now,
               updated_at: now
             })
           end)
           |> Map.update!(:resource_attempt, &Map.put(&1, :updated_at, now))
         end) do
      {:ok, updated_session} ->
        attempt_history(
          preview_session_to_context(context.host, updated_session, context.datashop_session_id)
        )

      _ ->
        {:error, "server error", 500}
    end
  end

  defp preview_write_file_record(
         %LegacySuperactivityContext{} = context,
         attempt_guid,
         user_id,
         file_name,
         content,
         mime_type,
         byte_encoding,
         activity_type,
         attempt_number
       ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    current_attempt_number = attempt_number || context.activity_attempt.attempt_number
    file_key = preview_file_record_key(current_attempt_number, file_name)
    preview_bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)
    storage_key = preview_storage_key(attempt_guid, current_attempt_number, file_name)
    max_file_bytes = preview_max_file_bytes()

    cond do
      byte_size(content) > max_file_bytes ->
        {:error, "file too large", 413}

      true ->
        with {:ok, %{status_code: 200}} <-
               put_preview_file_object(preview_bucket_name, storage_key, content, mime_type),
             {:ok, updated_session} <-
               PreviewSessions.update(attempt_guid, fn session ->
                 save_file = %{
                   attempt_guid: attempt_guid,
                   attempt_number: current_attempt_number,
                   user_id: user_id,
                   storage_key: storage_key,
                   mime_type: mime_type,
                   byte_encoding: byte_encoding,
                   activity_type: activity_type,
                   file_name: file_name,
                   file_guid: Ecto.UUID.generate(),
                   inserted_at: now,
                   size_bytes: byte_size(content)
                 }

                 Map.update!(session, :file_records, &Map.put(&1, file_key, save_file))
               end) do
          save_file = Map.fetch!(updated_session.file_records, file_key)

          xml =
            FileRecord.setup(%{
              context:
                preview_session_to_context(
                  context.host,
                  updated_session,
                  context.datashop_session_id
                ),
              date_created: DateTime.to_unix(save_file.inserted_at),
              file_name: save_file.file_name,
              guid: save_file.file_guid
            })
            |> XmlBuilder.document()
            |> XmlBuilder.generate()

          {:ok, xml}
        else
          {:ok, %{status_code: status_code}} when status_code not in [200, 204] ->
            {:error, "server error", 500}

          {:error, _reason} = update_error ->
            _ = delete_preview_file_object(preview_bucket_name, storage_key)

            case update_error do
              {:error, :not_found} -> {:error, "file not found", 404}
              _ -> {:error, "server error", 500}
            end

          _ ->
            {:error, "server error", 500}
        end
    end
  end

  defp preview_load_file_record(
         %LegacySuperactivityContext{} = context,
         attempt_guid,
         attempt_number,
         file_name
       ) do
    preview_bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

    with {:ok, session} <- PreviewSessions.get(attempt_guid),
         save_file when not is_nil(save_file) <-
           Map.get(
             session.file_records,
             preview_file_record_key(
               attempt_number || context.activity_attempt.attempt_number,
               file_name
             )
           ),
         {:ok, %{status_code: 200, body: body}} <-
           get_preview_file_object(preview_bucket_name, save_file.storage_key) do
      {:ok, body}
    else
      {:error, :not_found} -> {:error, "file not found", 404}
      {:error, _reason} -> {:error, "server error", 500}
      {:ok, %{status_code: 404}} -> {:error, "file not found", 404}
      nil -> {:error, "file not found", 404}
      _ -> {:error, "server error", 500}
    end
  end

  defp preview_file_directory(%LegacySuperactivityContext{} = context) do
    xml =
      FileDirectory.setup(%{
        context: context
      })
      |> XmlBuilder.document()
      |> XmlBuilder.generate()

    {:ok, xml}
  end

  defp preview_eval_numeric_score(
         %LegacySuperactivityContext{} = context,
         score,
         out_of,
         part_attempt
       ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case PreviewSessions.update(context.activity_attempt.attempt_guid, fn session ->
           session
           |> update_preview_part_attempt(part_attempt, fn current_part_attempt ->
             Map.merge(current_part_attempt, %{
               score: score,
               out_of: out_of,
               date_evaluated: now,
               updated_at: now
             })
           end)
           |> update_preview_activity_attempt(fn activity_attempt ->
             Map.merge(activity_attempt, %{
               score: score,
               out_of: out_of,
               updated_at: now
             })
           end)
           |> Map.update!(:resource_attempt, &Map.put(&1, :updated_at, now))
         end) do
      {:ok, updated_session} ->
        attempt_history(
          preview_session_to_context(context.host, updated_session, context.datashop_session_id)
        )

      _ ->
        {:error, "server error", 500}
    end
  end

  defp update_preview_activity_attempt(session, updater) do
    updated_activity_attempt = updater.(session.activity_attempt)

    session
    |> Map.put(:activity_attempt, updated_activity_attempt)
    |> Map.update!(:resource_attempt, fn resource_attempt ->
      Map.put(
        resource_attempt,
        :activity_attempts,
        replace_or_append_activity_attempt(
          resource_attempt.activity_attempts,
          updated_activity_attempt
        )
      )
    end)
  end

  defp update_preview_part_attempt(session, part_attempt, updater) do
    updated_part_attempts =
      Enum.map(session.activity_attempt.part_attempts, fn current_part_attempt ->
        if current_part_attempt.part_id == Map.get(part_attempt, :part_id) do
          updater.(current_part_attempt)
        else
          current_part_attempt
        end
      end)

    update_preview_activity_attempt(session, fn activity_attempt ->
      Map.put(activity_attempt, :part_attempts, updated_part_attempts)
    end)
  end

  defp replace_or_append_activity_attempt(activity_attempts, updated_activity_attempt) do
    case Enum.find_index(activity_attempts, fn activity_attempt ->
           activity_attempt.attempt_number == updated_activity_attempt.attempt_number
         end) do
      nil -> activity_attempts ++ [updated_activity_attempt]
      index -> List.replace_at(activity_attempts, index, updated_activity_attempt)
    end
  end

  defp preview_file_record_key(attempt_number, file_name) do
    {to_string(attempt_number), file_name}
  end

  defp finalize_activity_attempt(%LegacySuperactivityContext{} = context) do
    case context.activity_attempt.date_evaluated do
      nil ->
        part_attempts = Attempts.get_latest_part_attempts(context.activity_attempt.attempt_guid)

        # Ensures all parts are evaluated before rolling up the part scores into activity score
        # Note that by default assign 0 out of 100 is assumed for any part not already evaluated
        client_evaluations =
          Enum.reduce(part_attempts, [], fn p, acc ->
            case p.date_evaluated do
              nil -> [create_evaluation(context, 0, 100, p) | acc]
              _ -> [create_evaluation(context, p.score, p.out_of, p) | acc]
            end
          end)
          |> Enum.reverse()

        Repo.transaction(fn ->
          if length(client_evaluations) > 0 do
            ApplyClientEvaluation.apply(
              context.section.slug,
              context.activity_attempt.attempt_guid,
              client_evaluations,
              context.datashop_session_id
            )
          end
        end)

      _ ->
        {:ok, "activity already finalized"}
    end
  end

  defp create_evaluation(%LegacySuperactivityContext{} = context, score, out_of, part_attempt) do
    {:ok, feedback} = Feedback.parse(%{"id" => "1", "content" => "elsewhere"})

    user_input =
      case Enum.at(context.save_files, 0) do
        nil -> "some-input"
        _ -> Enum.at(context.save_files, 0).content
      end

    %{
      attempt_guid: part_attempt.attempt_guid,
      client_evaluation: %ClientEvaluation{
        input: %StudentInput{
          input: user_input
        },
        score: score,
        out_of: out_of,
        feedback: feedback
      }
    }
  end

  defp eval_numeric_score(%LegacySuperactivityContext{} = context, score, out_of, part_attempt) do
    Attempts.update_part_attempt(part_attempt, %{score: score, out_of: out_of})

    client_evaluations = [
      create_evaluation(context, score, out_of, part_attempt)
    ]

    case ApplyClientEvaluation.apply(
           context.section.slug,
           context.activity_attempt.attempt_guid,
           client_evaluations,
           context.datashop_session_id,
           no_roll_up: true
         ) do
      {:ok, _evaluations} ->
        attempt_history(
          fetch_delivery_context(
            context.host,
            context.user,
            context.activity_attempt.attempt_guid,
            context.datashop_session_id
          )
        )

      {:error, message} ->
        Logger.error("The error when applying client evaluation #{message}")
        {:error, "server error", 500}
    end
  end

  defp purse_score(score_type, score_value) do
    case score_type do
      "completed" ->
        {:non_numeric, score_value}

      "count" ->
        {:non_numeric, score_value}

      "feedback" ->
        {:non_numeric, score_value}

      "grade" ->
        {score, _} = Float.parse(score_value)
        {:numeric, score * 100, 100}

      "percent" ->
        {score, _} = Float.parse(score_value)
        {:numeric, score * 100, 100}

      "percentScore" ->
        {score, _} = Float.parse(score_value)
        {:numeric, score, 100}

      "posttest1Score" ->
        {score, _} = Float.parse(score_value)
        {:numeric, score * 100, 100}

      "posttest2Score" ->
        {score, _} = Float.parse(score_value)
        {:numeric, score * 100, 100}

      "pretestScore" ->
        {score, _} = Float.parse(score_value)
        {:numeric, score * 100, 100}

      "problem1Completed" ->
        {:non_numeric, score_value}

      "problem2Completed" ->
        {:non_numeric, score_value}

      "problem3Completed" ->
        {:non_numeric, score_value}

      "score" ->
        case String.split(score_value, ",", trim: true) do
          [numerator, denominator] ->
            {score, _} = Float.parse(numerator)
            {out_of, _} = Float.parse(denominator)
            {:numeric, score, out_of}

          _ ->
            {:non_numeric, score_value}
        end

      "status" ->
        {:non_numeric, score_value}

      "visited" ->
        {:non_numeric, score_value}
    end
  end

  defp attempt_history(%LegacySuperactivityContext{} = context) do
    xml =
      AttemptHistory.setup(%{
        context: context
      })
      |> XmlBuilder.document()
      |> XmlBuilder.generate()

    {:ok, xml}
  end

  defp get_timezone() do
    {zone, result} = System.cmd("date", ["+%Z"])
    if result == 0, do: String.trim(zone)
  end

  defp error(conn, code, reason) do
    conn
    |> Plug.Conn.send_resp(code, reason)
    |> Plug.Conn.halt()
  end

  defp import_error(conn, reason) do
    payload = import_error_payload(reason)

    conn
    |> Plug.Conn.put_status(400)
    |> json(payload)
    |> Plug.Conn.halt()
  end

  defp import_error_payload(:not_authorized) do
    %{
      code: "not_authorized",
      message: "You are not authorized to modify this activity.",
      status: 403,
      details: %{}
    }
  end

  defp import_error_payload(:not_found) do
    %{
      code: "activity_not_found",
      message: "The target activity could not be found.",
      status: 404,
      details: %{}
    }
  end

  defp import_error_payload(:invalid_package) do
    %{
      type: "error",
      result: "failure",
      code: "invalid_package",
      message: "The uploaded ZIP is not a valid embedded activity package.",
      details: %{}
    }
  end

  defp import_error_payload({:invalid_request, message}) when is_binary(message) do
    %{
      type: "error",
      result: "failure",
      code: "invalid_request",
      message: message,
      details: %{}
    }
  end

  defp import_error_payload({:missing_referenced_files, missing_files}) do
    %{
      type: "error",
      result: "failure",
      code: "missing_referenced_files",
      message: "The package manifest references files that are missing from the ZIP archive.",
      details: %{missing_files: missing_files}
    }
  end

  defp import_error_payload({:archive_file_count_exceeded, actual_file_count, max_file_count}) do
    %{
      type: "error",
      result: "failure",
      code: "archive_file_count_exceeded",
      message: "The ZIP archive contains too many files.",
      details: %{actual_file_count: actual_file_count, max_file_count: max_file_count}
    }
  end

  defp import_error_payload({:archive_entry_too_large, path, actual_bytes, max_bytes}) do
    %{
      type: "error",
      result: "failure",
      code: "archive_entry_too_large",
      message: "A file in the ZIP archive exceeds the allowed size.",
      details: %{path: path, actual_bytes: actual_bytes, max_bytes: max_bytes}
    }
  end

  defp import_error_payload({:archive_uncompressed_size_exceeded, actual_bytes, max_bytes}) do
    %{
      type: "error",
      result: "failure",
      code: "archive_uncompressed_size_exceeded",
      message: "The ZIP archive is too large when uncompressed.",
      details: %{actual_bytes: actual_bytes, max_bytes: max_bytes}
    }
  end

  defp import_error_payload({:supporting_file_staging_failed, reason}) do
    %{
      type: "error",
      result: "failure",
      code: "supporting_file_staging_failed",
      message: "The package files could not be staged for import.",
      details: %{reason: serialize_import_reason(reason)}
    }
  end

  defp import_error_payload({:supporting_file_backup_failed, reason}) do
    %{
      type: "error",
      result: "failure",
      code: "supporting_file_backup_failed",
      message: "Existing activity files could not be backed up before import.",
      details: %{reason: serialize_import_reason(reason)}
    }
  end

  defp import_error_payload({:supporting_file_promote_failed, reason}) do
    %{
      type: "error",
      result: "failure",
      code: "supporting_file_promote_failed",
      message: "The staged package could not be promoted into the activity bundle.",
      details: %{reason: serialize_import_reason(reason)}
    }
  end

  defp import_error_payload({:supporting_file_promote_failed, reason, rollback_reason}) do
    %{
      type: "error",
      result: "failure",
      code: "supporting_file_promote_failed",
      message: "The staged package could not be promoted into the activity bundle.",
      details: %{
        reason: serialize_import_reason(reason),
        rollback_reason: serialize_import_reason(rollback_reason)
      }
    }
  end

  defp import_error_payload(reason) do
    %{
      type: "error",
      result: "failure",
      code: "package_import_failed",
      message: "Unable to import embedded activity package.",
      details: %{reason: serialize_import_reason(reason)}
    }
  end

  defp serialize_import_reason({:staging_upload_failed, path}) do
    %{code: "staging_upload_failed", path: path}
  end

  defp serialize_import_reason({:backup_copy_failed, destination_key}) do
    %{code: "backup_copy_failed", destination_key: destination_key}
  end

  defp serialize_import_reason({:backup_lookup_failed, destination_key, reason}) do
    %{
      code: "backup_lookup_failed",
      destination_key: destination_key,
      reason: serialize_import_reason(reason)
    }
  end

  defp serialize_import_reason({:promote_copy_failed, destination_key, staged_key}) do
    %{
      code: "promote_copy_failed",
      destination_key: destination_key,
      staged_key: staged_key
    }
  end

  defp serialize_import_reason({:rollback_restore_failed, destination_key, backup_key}) do
    %{
      code: "rollback_restore_failed",
      destination_key: destination_key,
      backup_key: backup_key
    }
  end

  defp serialize_import_reason({:rollback_delete_failed, destination_key}) do
    %{code: "rollback_delete_failed", destination_key: destination_key}
  end

  defp serialize_import_reason({:rollback_missing_backup_record, destination_key}) do
    %{code: "rollback_missing_backup_record", destination_key: destination_key}
  end

  defp serialize_import_reason({:ok, value}), do: %{code: "ok", value: inspect(value)}
  defp serialize_import_reason(value) when is_atom(value), do: %{code: Atom.to_string(value)}
  defp serialize_import_reason(value) when is_binary(value), do: %{message: value}
  defp serialize_import_reason(value), do: %{message: inspect(value)}
end
