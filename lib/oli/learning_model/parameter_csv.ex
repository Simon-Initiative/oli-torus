defmodule Oli.LearningModel.ParameterCsv do
  @moduledoc """
  Project-scoped LKT-AOA CSV transfer. Reads compact projections through a cursor;
  imports are atomic and load a full revision only when copying an actual edit.
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
  alias Oli.Resources
  alias Oli.Resources.{ResourceType, Revision}

  @headers ["title", "resource_id", "children_ids", "beta_lo", "beta_difficulty"]
  @objective ResourceType.id_for_objective()
  @activity ResourceType.id_for_activity()
  @transfer_timeout :timer.minutes(2)

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
            |> Repo.stream(max_rows: 100)
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
  """
  @spec import(%Project{}, %Author{}, Enumerable.t()) ::
          {:ok, import_counts()} | {:error, String.t()}
  def import(project, author, lines) do
    with :ok <- authorize(project, author) do
      Repo.transaction(
        fn ->
          result =
            lines
            |> CSV.decode(headers: false)
            |> Enum.with_index(1)
            |> Enum.reduce(%{changed: 0, unchanged: 0, seen: MapSet.new()}, fn
              {{:ok, @headers}, 1}, acc ->
                acc

              {_, 1}, _acc ->
                Repo.rollback("Row 1: expected #{Enum.join(@headers, ",")} headers.")

              {{:error, _}, row}, _acc ->
                Repo.rollback("Row #{row}: malformed CSV.")

              {{:ok, values}, row}, acc ->
                import_row(project, author, values, row, acc)
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

  defp import_row(project, author, [_title, id, _children, beta, difficulties], row, acc) do
    with {id, ""} when id > 0 <- Integer.parse(id),
         false <- MapSet.member?(acc.seen, id),
         %{} = record <-
           Repo.one(from r in working_resources_query(project.id), where: r.resource_id == ^id),
         {:ok, parameters} <- parse_parameters(record, beta, difficulties),
         {:ok, mapping} <- lock_working_resource(record),
         {:ok, outcome} <- apply_parameters(record, mapping, parameters, author) do
      acc
      |> Map.update!(outcome, &(&1 + 1))
      |> Map.update!(:seen, &MapSet.put(&1, id))
    else
      {:error, message} ->
        Repo.rollback("Row #{row}: #{message}")

      _ ->
        Repo.rollback("Row #{row}: invalid, duplicate, deleted, or out-of-project resource ID.")
    end
  end

  defp import_row(_project, _author, _values, row, _acc),
    do: Repo.rollback("Row #{row}: expected five columns.")

  defp lock_working_resource(record) do
    # Lock the exact mapping we will update. Re-check both revision and publication
    # after waiting for the lock, since either may have changed during validation.
    mapping =
      Repo.one!(
        from pr in PublishedResource,
          where:
            pr.publication_id == ^record.publication_id and pr.resource_id == ^record.resource_id,
          lock: "FOR UPDATE"
      )

    publication = Repo.get!(Publication, record.publication_id)

    case is_nil(publication.published) and mapping.revision_id == record.id and
           Locks.expired_or_empty?(mapping) do
      true -> {:ok, mapping}
      false -> {:error, "resource is being edited; retry after editing finishes."}
    end
  end

  defp apply_parameters(record, mapping, parameters, author) do
    case effective_payload(record) == parameters.payload do
      true -> {:ok, :unchanged}
      false -> create_parameter_revision(record, mapping, parameters, author)
    end
  end

  defp create_parameter_revision(record, mapping, parameters, author) do
    # Only an actual edit needs the full revision, to preserve its content and history.
    previous = Repo.get!(Revision, record.id)

    with {:ok, revision} <-
           Resources.create_revision_from_previous(previous, %{
             author_id: author.id,
             learning_model_parameters: parameters
           }),
         {:ok, _} <- Publishing.update_published_resource(mapping, %{revision_id: revision.id}) do
      {:ok, :changed}
    else
      _ -> {:error, "could not save parameters."}
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
