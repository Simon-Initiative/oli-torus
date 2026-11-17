defmodule Oli.LearningModel.ParameterCsv do
  @moduledoc """
  Project-scoped LKT-AOA CSV transfer. Reads compact projections through a cursor. Imports
  run through `Oli.Authoring.Audited.import_learning_parameters/4`, which is atomic, copies
  changed revisions directly inside PostgreSQL, and records each one.
  Titles and children are informational. Missing parameters export as effective zeros.
  """

  import Ecto.Query

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course.Project
  alias Oli.LearningModel.{Parameters, PartIds}
  alias Oli.LearningModel.V2.{ActivityParameters, LearningObjectiveParameters, PartParameters}
  alias Oli.Publishing.{PublishedResource, Publications.Publication}
  alias Oli.Repo
  alias Oli.Resources.{ResourceType, Revision}

  @batch_size 250

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
            |> Repo.stream(max_rows: @batch_size)
            |> Stream.map(&export_row/1)

          Stream.concat([@headers], rows) |> CSV.encode() |> consume.()
        end,
        timeout: @transfer_timeout
      )
    end
  end

  @doc "The CSV header row shared by export and import."
  @spec headers() :: [String.t()]
  def headers, do: @headers

  @doc """
  Projects the working objectives and activities of the project with `project_id`, in resource
  order, with only the fields the transfer needs. Import narrows it to the rows it locked.
  """
  @spec working_resources_query(pos_integer()) :: Ecto.Query.t()
  # The projection retains only the content fields PartIds needs. Adaptive part
  # membership depends on layout types and rule conditions as well as authored IDs.
  # Keeping that shape lets us reuse PartIds rather than reimplement its rules in SQL.
  # Do not replace this projection with full revision content: courses can be large.
  def working_resources_query(project_id) do
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

  @doc """
  The parameters a projected resource has in effect: stored parameters, or zeros where none
  are stored, for every current part of an activity.
  """
  @spec effective_payload(map()) :: LearningObjectiveParameters.t() | ActivityParameters.t()
  def effective_payload(%{resource_type_id: @objective, parameters: nil}),
    do: %LearningObjectiveParameters{beta_lo: 0.0}

  def effective_payload(%{resource_type_id: @objective, parameters: parameters}),
    do: parameters.payload

  def effective_payload(%{resource_type_id: @activity} = record) do
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

  defp safe_title(title) do
    case String.trim_leading(title || "") do
      <<prefix::binary-size(1), _::binary>> when prefix in ["=", "+", "-", "@"] -> "'" <> title
      _ -> title || ""
    end
  end
end
