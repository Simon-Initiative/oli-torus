defmodule Oli.Interactives.Builds do
  @moduledoc "Coordinates author-authorized Interactive builds, handoffs and versioned activity updates."
  import Ecto.Query

  alias Oli.{Accounts, Activities, Interactives, Publishing, Repo}
  alias Oli.Authoring.{Course, Locks}
  alias Oli.Authoring.Editing.{ActivityEditor, PageEditor}
  alias Oli.Interactives.{AgentsClient, Build, BuildWorker, Bundle, Progress, Prompts}
  alias Oli.Publishing.{AuthoringResolver, PublishedResource}
  alias Oli.Resources.ResourceType

  @input_keys ~w(prompt revision_prompt selectedSkillIds model reasoning)
  @models ~w(gpt-6-astra gpt-6-sol)
  @efforts ~w(low medium high)
  @bundle_path "/workspace/outputs/interactive.zip"

  @doc "Saves generation inputs using the author's existing edit lock and transactionally queues one build."
  def start(project_slug, activity_id, author, params) do
    with {:ok, project, revision} <- authorize(project_slug, activity_id, author),
         {:ok, source} <- source_build(project, activity_id, revision),
         {:ok, inputs} <- validate_inputs(project_slug, params, source),
         lock_id when is_integer(lock_id) <- params["lockId"],
         lock_revision when not is_nil(lock_revision) <-
           AuthoringResolver.from_resource_id(project_slug, lock_id),
         true <-
           lock_revision.resource_type_id in [
             ResourceType.id_for_page(),
             ResourceType.id_for_activity()
           ] do
      Repo.transaction(fn ->
        history = revision.content["authoring"]["revision_prompts"] || []

        history =
          case source do
            nil -> history
            _ -> history ++ [inputs["revision_prompt"]]
          end

        inputs =
          inputs
          |> Map.put("revision_prompts", history)
          |> Map.put("source_build_id", source && source.id)

        model =
          put_in(
            revision.content,
            ["authoring"],
            Map.merge(
              revision.content["authoring"],
              Map.take(inputs, @input_keys ++ ["revision_prompts"])
            )
          )
          |> put_in(["authoring", "previewText"], inputs["prompt"])

        unwrap_edit!(
          ActivityEditor.edit(project_slug, lock_id, activity_id, author.email, %{
            "content" => Map.delete(model, "authoring"),
            "authoring" => model["authoring"]
          })
        )

        build =
          %Build{}
          |> Build.changeset(%{
            project_id: project.id,
            resource_id: activity_id,
            author_id: author.id,
            lock_id: lock_id,
            inputs: inputs
          })

        case Repo.insert(build) do
          {:ok, build} ->
            %{"build_id" => build.id} |> BuildWorker.new() |> Oban.insert!()
            build

          {:error, _} ->
            Repo.rollback("An Interactive build is already running for this activity.")
        end
      end)
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "The activity's edit lock is required."}
    end
  end

  @doc "Returns the latest build and canonical activity result, scoped to an authorized project/activity."
  def latest(project_slug, activity_id, author) do
    with {:ok, project, revision} <- authorize(project_slug, activity_id, author) do
      build =
        Repo.one(
          from b in Build,
            where: b.project_id == ^project.id and b.resource_id == ^activity_id,
            order_by: [desc: b.inserted_at, desc: b.id],
            limit: 1
        )

      {:ok, response(build, revision)}
    end
  end

  @doc "Loads a build through the same project/activity authorization as authoring."
  def get(project_slug, activity_id, id, author) do
    with {:ok, project, _} <- authorize(project_slug, activity_id, author),
         {:ok, id} <- Ecto.UUID.cast(id),
         %Build{} = build <-
           Repo.get_by(Build, id: id, project_id: project.id, resource_id: activity_id) do
      {:ok, build}
    else
      {:error, :not_authorized} -> {:error, :not_authorized}
      _ -> {:error, :not_found}
    end
  end

  @doc "Fences completion before stopping the provider; cleanup remains durable until cancellation is confirmed."
  def cancel(project_slug, activity_id, id, author, opts \\ []) do
    with {:ok, build} <- get(project_slug, activity_id, id, author),
         {:ok, build} <-
           Repo.transaction(fn ->
             current = Repo.one!(from b in Build, where: b.id == ^build.id, lock: "FOR UPDATE")

             case current.status do
               "queued" ->
                 save!(current, %{status: "cancelled"})

               status when status in ~w(launching running cancelling) ->
                 save!(current, %{status: "cancelling"})

               "cancelled" ->
                 current

               _ ->
                 Repo.rollback(:not_active)
             end
           end) do
      case build.status do
        "cancelling" -> cancel_remote(build, opts)
        _ -> :ok
      end

      {:ok, Repo.get!(Build, build.id)}
    end
  end

  @doc "Advances one persisted build. Oban snoozes between short provider polling operations."
  def advance(id, opts \\ []) do
    case Repo.get(Build, id) |> Repo.preload([:project, :author]) do
      nil ->
        :ok

      %{status: status} when status in ~w(completed failed cancelled) ->
        :ok

      build ->
        case DateTime.diff(DateTime.utc_now(), build.inserted_at) > 1800 do
          true -> fail(build, "Build timed out after 30 minutes.", opts)
          false -> advance_build(build, opts)
        end
    end
  end

  defp advance_build(%{status: "cancelling"} = build, opts), do: cancel_remote(build, opts)

  defp advance_build(%{status: "queued"} = build, opts) do
    {count, _} =
      Repo.update_all(from(b in Build, where: b.id == ^build.id and b.status == "queued"),
        set: [status: "launching"]
      )

    case count do
      1 ->
        result =
          with {:ok, files} <- source_files(build) do
            {instructions, prompt} = Prompts.authoring(build.inputs)

            Interactives.start_session(
              prompt,
              Keyword.merge(opts,
                app_files: files,
                model: build.inputs["model"],
                instructions: instructions,
                agent_options: %{
                  "reasoning" => %{"effort" => build.inputs["reasoning"]},
                  "tools" => [finish_tool()]
                }
              )
            )
          end

        case result do
          {:ok, %{"id" => session_id}} ->
            {count, _} =
              Repo.update_all(
                from(b in Build, where: b.id == ^build.id and b.status == "launching"),
                set: [status: "running", session_id: session_id]
              )

            case count do
              1 ->
                {:snooze, 5}

              _ ->
                current = Repo.get!(Build, build.id) |> save!(%{session_id: session_id})
                cancel_remote(current, opts)
            end

          {:error, message} when is_binary(message) ->
            launch_failed(build, message, false, opts)

          {:error, error} ->
            launch_failed(
              build,
              error.message <>
                case error[:creation_uncertain] do
                  true ->
                    " Session creation is uncertain; inspect OpenAI before starting another build."

                  _ ->
                    ""
                end,
              error[:creation_uncertain] == true,
              opts
            )
        end

      _ ->
        {:snooze, 5}
    end
  end

  defp advance_build(%{status: "launching"} = build, opts),
    do:
      fail(
        build,
        "Session launch was interrupted; inspect OpenAI before starting another build.",
        opts
      )

  defp advance_build(build, opts) do
    with {:ok, session} <- AgentsClient.get_session(build.session_id, opts),
         {:ok, turns} <- AgentsClient.latest_turn(build.session_id, opts) do
      turn = List.first(turns["data"] || []) || %{}
      actions = session["required_actions"] || []

      cond do
        session["status"] == "failed" or turn["status"] in ~w(failed cancelled) ->
          fail(build, "The authoring session failed or was cancelled.", opts)

        actions != [] ->
          acknowledge(build, actions, opts)

        turn["status"] == "completed" ->
          complete(build, turn, opts)

        true ->
          {:snooze, 5}
      end
    else
      {:error, %{kind: kind}} when kind in [:transport, :http] -> {:snooze, 10}
      _ -> fail(build, "Unable to read the authoring session.", opts)
    end
  end

  defp acknowledge(
         build,
         [%{"type" => "function_call", "name" => "finish_interactive"} = action],
         opts
       ) do
    build = save!(build, %{handoff: Map.take(action, ["turn_id", "call_id"])})

    case AgentsClient.submit_tool_result(
           build.session_id,
           action,
           Keyword.put(
             opts,
             :idempotency_key,
             "interactive-finish-#{build.id}-#{action["call_id"]}"
           )
         ) do
      {:ok, _} -> {:snooze, 5}
      {:error, _} -> {:snooze, 10}
    end
  end

  defp acknowledge(build, _, opts),
    do: fail(build, "The agent requested an unsupported external action.", opts)

  defp complete(build, turn, opts) do
    with true <- build.handoff["turn_id"] == turn["id"],
         {:ok, artifact} <- find_artifact(build.session_id, turn["id"], nil, opts),
         true <- artifact["size_bytes"] <= 20_000_000,
         {:ok, zip} <- AgentsClient.artifact_content(build.session_id, artifact["id"], opts),
         {:ok, unpacked} <- Bundle.unpack(zip, build.inputs["selectedSkillIds"]),
         {:ok, location} <- Bundle.upload(unpacked, build.id) do
      Progress.capture(build, opts)

      case persist_result(build, unpacked.parts, location) do
        {:ok, _} ->
          AgentsClient.delete_session(build.session_id, opts)
          :ok

        {:error, :cancelled} ->
          Bundle.cleanup(unpacked.files, build.id)
          cancel_remote(Repo.get!(Build, build.id), opts)

        {:error, _} ->
          Bundle.cleanup(unpacked.files, build.id)

          fail(
            build,
            "The activity changed or its edit lock was lost. Reload the activity before building again.",
            opts
          )
      end
    else
      {:error, message} when is_binary(message) -> fail(build, message, opts)
      _ -> fail(build, "The agent did not return a valid finished ZIP for this build.", opts)
    end
  end

  defp find_artifact(session_id, turn_id, cursor, opts) do
    with {:ok, page} <- AgentsClient.artifacts_page(session_id, cursor, opts) do
      case Enum.find(page["data"], &(&1["turn_id"] == turn_id and &1["path"] == @bundle_path)) do
        nil ->
          case {page["has_more"], page["last_id"]} do
            {true, next} when is_binary(next) and next != cursor ->
              find_artifact(session_id, turn_id, next, opts)

            _ ->
              {:error, "The completed session did not publish interactive.zip."}
          end

        artifact ->
          {:ok, artifact}
      end
    end
  end

  defp persist_result(build, parts, location) do
    Repo.transaction(fn ->
      current = Repo.one!(from b in Build, where: b.id == ^build.id, lock: "FOR UPDATE")

      case current.status do
        "running" -> :ok
        _ -> Repo.rollback(:cancelled)
      end

      publication = Publishing.project_working_publication(build.project.slug)

      Repo.one!(
        from pr in PublishedResource,
          where: pr.publication_id == ^publication.id and pr.resource_id == ^build.resource_id,
          lock: "FOR UPDATE"
      )

      {:ok, _, revision} = authorize(build.project.slug, build.resource_id, build.author)

      case Map.take(revision.content["authoring"], @input_keys) ==
             Map.take(build.inputs, @input_keys) and
             get_in(revision.content, ["bundle", "buildId"]) == build.inputs["source_build_id"] do
        false -> Repo.rollback(:stale_inputs)
        true -> :ok
      end

      authoring_parts =
        Enum.map(
          parts,
          &%{"id" => &1["id"], "scoringStrategy" => "average", "responses" => [], "hints" => []}
        )

      model =
        revision.content
        |> Map.put("bundle", location)
        |> put_in(["authoring", "parts"], authoring_parts)
        |> put_in(["authoring", "revision_prompt"], "")
        |> put_in(["authoring", "revision_prompts"], build.inputs["revision_prompts"] || [])

      objectives = Map.new(parts, &{&1["id"], Enum.uniq(&1["objectiveIds"])})

      lock_mapping = Publishing.get_published_resource!(publication.id, build.lock_id)
      release_lock? = lock_mapping.locked_by_id != build.author_id

      case Locks.acquire(build.project.slug, publication.id, build.lock_id, build.author_id) do
        {:acquired} -> :ok
        _ -> Repo.rollback(:lock_lost)
      end

      unwrap_edit!(
        ActivityEditor.edit(
          build.project.slug,
          build.lock_id,
          build.resource_id,
          build.author.email,
          %{
            "content" => Map.delete(model, "authoring"),
            "authoring" => model["authoring"],
            "releaseLock" => release_lock?,
            "objectives" => objectives
          }
        )
      )

      save!(build, %{status: "completed"})
    end)
  end

  defp fail(build, message, opts) do
    {count, _} =
      Repo.update_all(
        from(b in Build, where: b.id == ^build.id and b.status in ~w(queued launching running)),
        set: [status: "failed", error: message]
      )

    case count do
      1 ->
        case build.session_id do
          nil ->
            :ok

          id ->
            AgentsClient.cancel_session(id, opts)
            Progress.capture(build, opts)
            AgentsClient.delete_session(id, opts)
            :ok
        end

      _ ->
        case Repo.get!(Build, build.id) do
          %{status: "cancelling"} = current -> cancel_remote(current, opts)
          _ -> :ok
        end
    end
  end

  defp launch_failed(build, message, uncertain, opts) do
    current = Repo.get!(Build, build.id)

    case {current.status, uncertain} do
      {"cancelling", false} ->
        mark_cancelled(current)

      {"cancelling", true} ->
        save!(current, %{
          status: "failed",
          error:
            "Cancellation could not be confirmed because session creation was uncertain. " <>
              message
        })

        :ok

      _ ->
        fail(current, message, opts)
    end
  end

  defp cancel_remote(%{session_id: nil}, _opts), do: {:snooze, 2}

  defp cancel_remote(build, opts) do
    result =
      with {:ok, _} <- AgentsClient.cancel_session(build.session_id, opts) do
        Progress.capture(build, opts)
        AgentsClient.delete_session(build.session_id, opts)
      end

    case result do
      {:ok, _} -> mark_cancelled(build)
      {:error, %{status: 404}} -> mark_cancelled(build)
      _ -> {:snooze, 2}
    end
  end

  defp mark_cancelled(build) do
    Repo.update_all(from(b in Build, where: b.id == ^build.id and b.status == "cancelling"),
      set: [status: "cancelled"]
    )

    :ok
  end

  defp authorize(project_slug, activity_id, %Accounts.Author{} = author) do
    with project when not is_nil(project) <- Course.get_project_by_slug(project_slug),
         true <- Accounts.can_access?(author, project),
         revision when not is_nil(revision) <-
           AuthoringResolver.from_resource_id(project_slug, activity_id),
         false <- revision.deleted,
         type_id when is_integer(type_id) <- revision.activity_type_id,
         %{slug: "oli_interactive"} <- Activities.get_registration(type_id) do
      {:ok, project, revision}
    else
      _ -> {:error, :not_authorized}
    end
  end

  defp authorize(_, _, _), do: {:error, :not_authorized}

  defp source_build(project, activity_id, revision) do
    case get_in(revision.content, ["bundle", "buildId"]) do
      nil ->
        {:ok, nil}

      id ->
        case Ecto.UUID.cast(id) do
          {:ok, id} ->
            case Repo.get_by(Build,
                   id: id,
                   project_id: project.id,
                   resource_id: activity_id,
                   status: "completed"
                 ) do
              nil -> {:error, "The current bundle has no completed build to revise."}
              build -> {:ok, build}
            end

          _ ->
            {:error, "The current bundle has no completed build to revise."}
        end
    end
  end

  defp source_files(build) do
    case build.inputs["source_build_id"] do
      nil ->
        {:ok, %{}}

      id ->
        case Repo.get_by(Build,
               id: id,
               project_id: build.project_id,
               resource_id: build.resource_id,
               status: "completed"
             ) do
          nil ->
            {:error, "The source Interactive build is no longer available."}

          source ->
            with {:ok, unpacked} <- Bundle.load(source.id, source.inputs["selectedSkillIds"]) do
              {:ok, unpacked.files}
            end
        end
    end
  end

  defp validate_inputs(project_slug, params, source) do
    revising = not is_nil(source)

    prompt =
      case revising do
        true -> source.inputs["prompt"]
        false -> params["prompt"]
      end

    revision_prompt =
      case revising do
        true -> params["revisionPrompt"]
        false -> ""
      end

    request_prompt =
      case revising do
        true -> revision_prompt
        false -> prompt
      end

    objectives =
      AuthoringResolver.revisions_of_type(project_slug, ResourceType.id_for_objective())
      |> PageEditor.construct_parent_references()

    roots = objectives |> Enum.filter(&is_nil(&1.parentIds)) |> Enum.map(& &1.id) |> MapSet.new()

    skills =
      Enum.filter(objectives, fn o -> Enum.any?(o.parentIds || [], &MapSet.member?(roots, &1)) end)

    selected = params["selectedSkillIds"]

    valid =
      is_binary(request_prompt) and String.trim(request_prompt) != "" and
        byte_size(request_prompt) <= 100_000 and
        params["model"] in @models and params["reasoning"] in @efforts and
        is_list(selected) and length(selected) > 0 and
        Enum.all?(selected, fn id -> Enum.any?(skills, &(&1.id == id)) end)

    case valid do
      true ->
        {:ok,
         params
         |> Map.take(@input_keys)
         |> Map.put("prompt", prompt)
         |> Map.put("revision_prompt", revision_prompt)
         |> Map.put(
           "skills",
           Enum.filter(skills, &(&1.id in selected))
           |> Enum.map(&%{"id" => &1.id, "title" => &1.title})
         )}

      false ->
        {:error,
         "Enter a prompt, select project skills, and choose a supported model and reasoning level."}
    end
  end

  defp response(nil, _), do: %{build: nil}

  defp response(build, revision) do
    result = %{
      build: %{
        id: build.id,
        status: build.status,
        error: build.error,
        transcript: build.transcript
      }
    }

    case build.status in ~w(queued launching running cancelling) or
           (build.status == "completed" and
              get_in(revision.content, ["bundle", "buildId"]) == build.id) do
      true ->
        Map.put(result, :activity, %{model: revision.content, objectives: revision.objectives})

      false ->
        result
    end
  end

  defp save!(build, attrs), do: build |> Build.changeset(attrs) |> Repo.update!()
  defp unwrap_edit!({:ok, revision}), do: revision

  defp unwrap_edit!(_),
    do: Repo.rollback("The activity edit lock could not be acquired. Reload and try again.")

  defp finish_tool do
    %{
      "type" => "function",
      "name" => "finish_interactive",
      "description" =>
        "Notify Torus that the tested static bundle is ready at /workspace/outputs/interactive.zip. Call once after validating the ZIP, then end the turn.",
      "parameters" => %{
        "type" => "object",
        "properties" => %{},
        "required" => [],
        "additionalProperties" => false
      }
    }
  end
end
