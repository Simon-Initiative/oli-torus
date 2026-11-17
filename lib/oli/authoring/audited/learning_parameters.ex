defmodule Oli.Authoring.Audited.LearningParameters do
  @moduledoc false

  # Learning model parameter import of `Oli.Authoring.Audited`, which validates its arguments.
  # Moved from `Oli.LearningModel.ParameterCsv.import/3`; `ParameterCsv` keeps the
  # authorization, the export, and the projection both directions share. Each changed resource
  # records `authoring_content_replaced` with `reason` `"parameter_csv"` in the import's
  # transaction.
  #
  # Imports CSV lines atomically, returning changed and unchanged resource counts.
  #
  # Titles and children are informational; only parameter values are applied. Missing
  # stored parameters compare as zero, so downloading and re-uploading defaults is a
  # no-op. An invalid row or an authoring lock rolls back the entire import.
  #
  # Batches use `@batch_size` rows. Each batch locks and reads resources together,
  # inserts changed revisions with INSERT … SELECT, and updates mappings in bulk.
  # The final batch may be smaller; batches never commit independently.

  import Ecto.Query
  import Oli.Authoring.Audited.Support, only: [record_many: 2, replacement: 4]

  alias Oli.Authoring.Locks
  alias Oli.LearningModel.{ParameterCsv, Parameters, PartIds}
  alias Oli.Publishing
  alias Oli.Publishing.{PublishedResource, Publications.Publication}
  alias Oli.Repo
  alias Oli.Resources.{ResourceType, Revision}

  @batch_size 250
  @headers ParameterCsv.headers()
  @objective ResourceType.id_for_objective()
  @activity ResourceType.id_for_activity()
  @transfer_timeout :timer.minutes(2)

  # Copy every persisted field, including embeds, without loading revision content.
  # Only identity, ancestry, attribution, parameters, and timestamps change.
  @copied_revision_columns Revision.__schema__(:fields)
                           |> Enum.reject(
                             &(&1 in [
                                 :id,
                                 :previous_revision_id,
                                 :author_id,
                                 :learning_model_parameters,
                                 :inserted_at,
                                 :updated_at
                               ])
                           )
                           |> Enum.map(&Revision.__schema__(:field_source, &1))
                           |> Enum.map_join(", ", &~s("#{&1}"))

  ## Commands

  def import_learning_parameters(context, project, author, lines) do
    with :ok <- ParameterCsv.authorize(project, author) do
      Repo.transaction(
        fn ->
          publication = Publishing.project_working_publication(project.slug)

          case publication do
            nil -> Repo.rollback("The project has no working publication.")
            _ -> :ok
          end

          result =
            lines
            |> CSV.decode(headers: false)
            |> Stream.with_index(1)
            |> Stream.reject(fn
              {{:ok, @headers}, 1} -> true
              {_, 1} -> Repo.rollback("Row 1: expected #{Enum.join(@headers, ",")} headers.")
              _ -> false
            end)
            |> Stream.chunk_every(@batch_size)
            |> Enum.reduce(%{changed: 0, unchanged: 0, seen: MapSet.new()}, fn batch, acc ->
              import_batch(context, project, publication, author, batch, acc)
            end)

          case MapSet.size(result.seen) do
            0 -> Repo.rollback("The CSV must contain at least one resource.")
            _ -> Map.take(result, [:changed, :unchanged])
          end
        end,
        timeout: @transfer_timeout
      )
    end
  end

  defp import_batch(context, project, publication, author, batch, acc) do
    {rows, seen} = Enum.map_reduce(batch, acc.seen, &parse_row/2)
    resource_ids = Enum.map(rows, & &1.resource_id)

    # Acquire mapping locks in resource order before reading parameter projections.
    # The locks remain held until the entire CSV transaction commits or rolls back.
    mappings =
      Repo.all(
        from pr in PublishedResource,
          where: pr.publication_id == ^publication.id and pr.resource_id in ^resource_ids,
          order_by: pr.resource_id,
          lock: "FOR UPDATE"
      )
      |> Map.new(&{&1.resource_id, &1})

    # Publishing also acquires mapping locks. Recheck after waiting so an import
    # cannot modify a publication that finished publishing while we were blocked.
    case Repo.exists?(
           from p in Publication, where: p.id == ^publication.id and is_nil(p.published)
         ) do
      true -> :ok
      false -> Repo.rollback("The working publication changed; download a fresh CSV and retry.")
    end

    records =
      Repo.all(
        from r in ParameterCsv.working_resources_query(project.id),
          where: r.resource_id in ^resource_ids
      )
      |> Map.new(&{&1.resource_id, &1})

    changes =
      Enum.flat_map(rows, fn row ->
        with %{} = mapping <- Map.get(mappings, row.resource_id),
             %{} = record <- Map.get(records, row.resource_id),
             true <- mapping.revision_id == record.id,
             {:ok, parameters} <- parse_parameters(record, row.beta, row.difficulties) do
          case Locks.expired_or_empty?(mapping) do
            false ->
              Repo.rollback(
                "Row #{row.number}: resource is being edited; retry after editing finishes."
              )

            true ->
              :ok
          end

          case ParameterCsv.effective_payload(record) == parameters.payload do
            true ->
              []

            false ->
              {:ok, encoded} = Parameters.encode(parameters)
              [%{previous_revision_id: record.id, parameters: encoded}]
          end
        else
          {:error, message} ->
            Repo.rollback("Row #{row.number}: #{message}")

          _ ->
            Repo.rollback("Row #{row.number}: invalid, deleted, or out-of-project resource ID.")
        end
      end)

    replacements = create_parameter_revisions(changes, publication.id, author.id)

    case record_many(context, Enum.map(replacements, &parameters_replaced(project, records, &1))) do
      :ok -> :ok
      {:error, reason} -> Repo.rollback(reason)
    end

    changed = length(replacements)

    %{
      changed: acc.changed + changed,
      unchanged: acc.unchanged + length(rows) - changed,
      seen: seen
    }
  end

  defp parse_row({{:ok, [_title, id, _children, beta, difficulties]}, number}, seen) do
    with {id, ""} when id > 0 <- Integer.parse(id),
         false <- MapSet.member?(seen, id) do
      {%{resource_id: id, beta: beta, difficulties: difficulties, number: number},
       MapSet.put(seen, id)}
    else
      _ -> Repo.rollback("Row #{number}: invalid or duplicate resource ID.")
    end
  end

  defp parse_row({{:ok, _}, number}, _seen),
    do: Repo.rollback("Row #{number}: expected five columns.")

  defp parse_row({{:error, _}, number}, _seen),
    do: Repo.rollback("Row #{number}: malformed CSV.")

  defp create_parameter_revisions([], _publication_id, _author_id), do: []

  defp create_parameter_revisions(changes, publication_id, author_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    # Values are bound parameters; the column list comes only from the Ecto schema.
    # Parameters and part membership were validated against the locked revisions.
    # Titles are unchanged, so successors retain their existing slugs.
    %{rows: revisions, num_rows: inserted} =
      Ecto.Adapters.SQL.query!(
        Repo,
        """
        INSERT INTO revisions (
          #{@copied_revision_columns}, previous_revision_id, author_id,
          learning_model_parameters, inserted_at, updated_at
        )
        SELECT old.#{String.replace(@copied_revision_columns, ", ", ", old.")},
          old.id, $2::bigint, updates.parameters, $3::timestamp, $3::timestamp
        FROM revisions AS old
        JOIN jsonb_to_recordset($1::jsonb)
          AS updates(previous_revision_id bigint, parameters jsonb)
          ON old.id = updates.previous_revision_id
        RETURNING id, resource_id, previous_revision_id
        """,
        [changes, author_id, now]
      )

    replacements =
      Enum.map(revisions, fn [id, resource_id, previous_revision_id] ->
        %{revision_id: id, resource_id: resource_id, previous_revision_id: previous_revision_id}
      end)

    %{num_rows: updated} =
      Ecto.Adapters.SQL.query!(
        Repo,
        """
        UPDATE published_resources AS mapping
        SET revision_id = updates.revision_id, updated_at = $3::timestamp
        FROM jsonb_to_recordset($1::jsonb)
          AS updates(revision_id bigint, resource_id bigint, previous_revision_id bigint)
        WHERE mapping.publication_id = $2::bigint
          AND mapping.resource_id = updates.resource_id
          AND mapping.revision_id = updates.previous_revision_id
        """,
        [replacements, publication_id, now]
      )

    case inserted == length(changes) and updated == inserted do
      true -> replacements
      false -> Repo.rollback("The working revisions changed; download a fresh CSV and retry.")
    end
  end

  defp parameters_replaced(project, records, created) do
    record = Map.fetch!(records, created.resource_id)

    previous = %{
      id: created.previous_revision_id,
      resource_id: record.resource_id,
      title: record.title,
      slug: nil
    }

    replacement(project, previous, %{previous | id: created.revision_id}, "parameter_csv")
  end

  defp parse_parameters(%{resource_type_id: @objective}, beta, "") do
    case Float.parse(beta) do
      {value, ""} -> decode_parameters("learning_objective", %{"beta_lo" => value})
      _ -> {:error, "beta_lo must be a finite number."}
    end
  end

  defp parse_parameters(%{resource_type_id: @activity} = record, "", difficulties) do
    with {:ok, values} when is_map(values) <- Jason.decode(difficulties),
         true <- MapSet.new(Map.keys(values)) == PartIds.for_content(record.part_content) do
      decode_parameters("activity", %{
        "parts" =>
          Map.new(values, fn {id, value} ->
            {id, %{"beta_difficulty" => value}}
          end)
      })
    else
      _ -> {:error, "beta_difficulty must be a JSON object containing every current part ID."}
    end
  end

  defp parse_parameters(_, _, _),
    do: {:error, "use beta_lo for objectives and beta_difficulty for activities."}

  defp decode_parameters(type, payload) do
    case Parameters.decode(%{
           schema_version: 1,
           model: "lkt_aoa",
           model_version: 2,
           parameter_type: type,
           payload: payload
         }) do
      {:ok, parameters} -> {:ok, parameters}
      _ -> {:error, "parameter values must be finite numbers."}
    end
  end
end
