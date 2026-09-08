defmodule Oli.LearningModel.ParameterCsv do
  @moduledoc """
  Project-scoped LKT-AOA CSV transfer. Reads compact projections through a cursor;
  imports are atomic and copy changed revisions directly inside PostgreSQL.
  Titles and children are informational. Missing parameters export as effective zeros.
  """

  import Ecto.Query

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Locks
  alias Oli.LearningModel.{Parameters, PartIds}
  alias Oli.LearningModel.V2.{ActivityParameters, LearningObjectiveParameters, PartParameters}
  alias Oli.Publishing
  alias Oli.Publishing.{PublishedResource, Publications.Publication}
  alias Oli.Repo
  alias Oli.Resources.{ResourceType, Revision}

  @batch_size 250

  @headers ["title", "resource_id", "children_ids", "beta_lo", "beta_difficulty"]
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

  @type import_counts :: %{changed: non_neg_integer(), unchanged: non_neg_integer()}

  @doc "Checks the content-admin authorization required for both transfer directions."
  @spec authorize(%Project{}, %Author{}) ::
          :ok | {:error, String.t()}
  def authorize(project, author) do
    case Accounts.at_least_content_admin?(author) and project.status == :active and
           Accounts.can_access?(author, project) do
      true -> :ok
      false -> {:error, "Content administrator access is required."}
    end
  end

  @doc """
  Passes encoded CSV lines to `consume` inside a database transaction.

  The callback must consume the stream before returning; it cannot return the lazy
  stream for later use. Its return value is wrapped in `{:ok, result}`.
  """
  @spec export(%Project{}, %Author{}, (Enumerable.t() -> result)) ::
          {:ok, result} | {:error, String.t()}
        when result: term()
  def export(project, author, consume) do
    with :ok <- authorize(project, author) do
      Repo.transaction(
        fn ->
          rows =
            working_resources_query(project.id)
            |> Repo.stream(max_rows: @batch_size)
            |> Stream.map(&export_row/1)

          Stream.concat([@headers], rows) |> CSV.encode() |> consume.()
        end,
        timeout: @transfer_timeout
      )
    end
  end

  @doc """
  Imports CSV lines atomically, returning changed and unchanged resource counts.

  Titles and children are informational; only parameter values are applied. Missing
  stored parameters compare as zero, so downloading and re-uploading defaults is a
  no-op. An invalid row or an authoring lock rolls back the entire import.

  Batches use `@batch_size` rows. Each batch locks and reads resources together,
  inserts changed revisions with INSERT … SELECT, and updates mappings in bulk.
  The final batch may be smaller; batches never commit independently.
  """
  @spec import(%Project{}, %Author{}, Enumerable.t()) ::
          {:ok, import_counts()} | {:error, String.t()}
  def import(project, author, lines) do
    with :ok <- authorize(project, author) do
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
            |> Enum.with_index(1)
            |> Stream.reject(fn
              {{:ok, @headers}, 1} -> true
              {_, 1} -> Repo.rollback("Row 1: expected #{Enum.join(@headers, ",")} headers.")
              _ -> false
            end)
            |> Stream.chunk_every(@batch_size)
            |> Enum.reduce(%{changed: 0, unchanged: 0, seen: MapSet.new()}, fn batch, acc ->
              import_batch(project, publication, author, batch, acc)
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

  # The projection retains only the content fields PartIds needs. Adaptive part
  # membership depends on layout types and rule conditions as well as authored IDs.
  # Keeping that shape lets us reuse PartIds rather than reimplement its rules in SQL.
  # Do not replace this projection with full revision content: courses can be large.
  defp working_resources_query(project_id) do
    from r in Revision,
      join: pr in PublishedResource,
      on: pr.revision_id == r.id,
      join: p in Publication,
      on: p.id == pr.publication_id,
      where:
        p.project_id == ^project_id and is_nil(p.published) and not r.deleted and
          r.resource_type_id in [@objective, @activity],
      order_by: r.resource_id,
      select: %{
        id: r.id,
        resource_id: r.resource_id,
        title: r.title,
        children: r.children,
        resource_type_id: r.resource_type_id,
        parameters: r.learning_model_parameters,
        publication_id: p.id,
        part_content:
          fragment(
            """
            (
              SELECT jsonb_strip_nulls(jsonb_build_object(
                'advancedDelivery', content->'advancedDelivery',
                'advancedAuthoring', content->'advancedAuthoring',
                'partsLayout', CASE WHEN jsonb_typeof(content->'partsLayout') = 'array' THEN (
                  SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'id', part->'id', 'type', part->'type'
                  )), '[]'::jsonb)
                  FROM jsonb_array_elements(content->'partsLayout') part
                ) END,
                'authoring', jsonb_build_object(
                  'parts', (
                    SELECT COALESCE(jsonb_agg(
                      CASE WHEN jsonb_typeof(part) = 'string' THEN part
                        ELSE jsonb_build_object('id', part->'id', 'type', part->'type')
                      END
                    ), '[]'::jsonb)
                    FROM jsonb_array_elements(
                      CASE WHEN jsonb_typeof(content->'authoring'->'parts') = 'array'
                        THEN content->'authoring'->'parts' ELSE '[]'::jsonb
                      END
                    ) part
                  ),
                  'rules', (
                    SELECT COALESCE(jsonb_agg(jsonb_build_object(
                      'disabled', rule->'disabled', 'conditions', rule->'conditions'
                    )), '[]'::jsonb)
                    FROM jsonb_array_elements(
                      CASE WHEN jsonb_typeof(content->'authoring'->'rules') = 'array'
                        THEN content->'authoring'->'rules' ELSE '[]'::jsonb
                      END
                    ) rule
                  )
                )
              ))
              FROM (SELECT ? AS content) source
            )
            """,
            r.content
          )
      }
  end

  defp effective_payload(%{resource_type_id: @objective, parameters: nil}),
    do: %LearningObjectiveParameters{beta_lo: 0.0}

  defp effective_payload(%{resource_type_id: @objective, parameters: parameters}),
    do: parameters.payload

  defp effective_payload(%{resource_type_id: @activity} = record) do
    stored_parts =
      case record.parameters do
        nil -> %{}
        %Parameters{payload: %ActivityParameters{parts: parts}} -> parts
      end

    parts =
      Map.new(PartIds.for_content(record.part_content), fn id ->
        {id, Map.get(stored_parts, id, %PartParameters{beta_difficulty: 0.0})}
      end)

    %ActivityParameters{parts: parts}
  end

  defp export_row(record) do
    case effective_payload(record) do
      %LearningObjectiveParameters{beta_lo: beta} ->
        [
          safe_title(record.title),
          record.resource_id,
          Jason.encode!(record.children || []),
          beta,
          ""
        ]

      %ActivityParameters{parts: parts} ->
        values = Map.new(parts, fn {id, parameters} -> {id, parameters.beta_difficulty} end)
        [safe_title(record.title), record.resource_id, "", "", Jason.encode!(values)]
    end
  end

  defp import_batch(project, publication, author, batch, acc) do
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
        from r in working_resources_query(project.id), where: r.resource_id in ^resource_ids
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

          case effective_payload(record) == parameters.payload do
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

    changed = create_parameter_revisions(changes, publication.id, author.id)

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

  defp create_parameter_revisions([], _publication_id, _author_id), do: 0

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
      true -> inserted
      false -> Repo.rollback("The working revisions changed; download a fresh CSV and retry.")
    end
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

  defp safe_title(title) do
    case String.trim_leading(title || "") do
      <<prefix::binary-size(1), _::binary>> when prefix in ["=", "+", "-", "@"] -> "'" <> title
      _ -> title || ""
    end
  end
end
