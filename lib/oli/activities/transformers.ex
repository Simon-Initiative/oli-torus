defmodule Oli.Activities.Transformers do
  alias Oli.Activities.Model

  require Logger

  @supported_transformations_by_operation [
    {:variable_substitution, Oli.Activities.Transformers.VariableSubstitution},
    {:shuffle, Oli.Activities.Transformers.Shuffle}
  ]

  @doc """
  Transforms a collection of activity revisions, batching the execution of the "context gathering"
  step of each transformation operation type.

  Returns a list of transformation results, where each entry is one of:

  {:ok, nil} -> No transformations were present in the revision content
  {:ok, transformed_model} -> transformed_model is the newly transformed activity model
  {:error, e} -> an error was encountered in either parsing of the model or execution of transformation.
  """
  def apply_transforms(revisions) when is_list(revisions) do
    # We transform raw, unparsed models, so create a repository of those, keyed by revision id
    model_repository = Enum.reduce(revisions, %{}, fn r, m -> Map.put(m, r.id, r.content) end)

    # Parse the models, and create a list of tuples of the revision and the parse result
    parsed_models = Enum.map(revisions, fn r -> {r, Model.parse(r.content)} end)

    parsing_errors_by_id = index_parsing_errors(parsed_models)

    # Create a MapSet of all revision ids that parsed successfully and that have at least one transformation
    has_transformation =
      Enum.filter(parsed_models, fn {_, parsed_model_result} ->
        case parsed_model_result do
          {:ok, parsed_model} -> Enum.count(parsed_model.transformations) > 0
          _ -> false
        end
      end)
      |> Enum.map(fn {rev, _} -> rev.id end)
      |> MapSet.new()

    # Group the transformers by type and batch execute their context creation and individually
    # apply their transforms
    {model_repository, transform_errors} =
      group_by_operation(parsed_models)
      |> batch_execute(model_repository)

    # Now map our original list of revisions to the result of the transformation.
    Enum.map(revisions, fn r ->
      if MapSet.member?(has_transformation, r.id) do
        if Map.has_key?(transform_errors, r.id) do
          {:error, Map.get(transform_errors, r.id)}
        else
          {:ok, Map.get(model_repository, r.id)}
        end
      else
        if Map.has_key?(parsing_errors_by_id, r.id) do
          {:error, Map.get(parsing_errors_by_id, r.id)}
        else
          {:ok, nil}
        end
      end
    end)
  end

  # Executes all transformations, grouped by operation (aka, their "type"), in a manner
  # that gathers any required context in a batch manner.
  #
  # Takes a map of operations as keys, with values being a list of tuples of revision id
  # and transformation.  Second argument is a map of revision models, keyed by their revision
  # id.
  #
  # Returns a tuple with the first element being the updated map of revision models and the
  # second element being a map of revision ids to errors encountered.
  defp batch_execute(by_operation, model_repository) do
    @supported_transformations_by_operation
    |> Enum.reduce({model_repository, %{}}, fn {operation, module},
                                               {model_repository, errors_by_id} ->
      case Map.get(by_operation, operation) do
        nil ->
          {model_repository, errors_by_id}

        revision_id_transform_pairs ->
          run_one_operation(model_repository, module, revision_id_transform_pairs, errors_by_id)
      end
    end)
  end

  # Run one batch of transformers, for a specific operation.
  #
  # Takes the model repository, the module of the transformer impl, and a list of
  # tuples of revision ids and transformer.  The revision_id_transform_pairs argument is really our
  # "batch" of work.
  #
  # Returns a tuple with first element being the new model_repository, and second being a map of
  # revision ids to errors, for those that errored
  defp run_one_operation(model_repository, module, revision_id_transform_pairs, errors_by_id) do
    transformers = Enum.map(revision_id_transform_pairs, fn {_, t} -> t end)

    # Generate the batch context
    case apply(module, :provide_batch_context, [transformers]) do
      {:ok, batch_context} ->
        # Now that we have the context for each transformer, go ahead and run
        # that single transformer and update the model repository with its results
        Enum.zip(batch_context, revision_id_transform_pairs)
        |> Enum.reduce({model_repository, errors_by_id}, fn {context, {id, t}},
                                                            {model_repository, errors_by_id} ->
          case apply(module, :transform, [Map.get(model_repository, id), t, context]) do
            {:ok, model} ->
              {Map.put(model_repository, id, model), errors_by_id}

            {:error, e} ->
              {model_repository, Map.put(errors_by_id, id, e)}
          end
        end)

      {:error, e} ->
        # add an entry for all revisions that used this operation, since their batch context
        # gathering step failed
        errors_by_id =
          Enum.map(revision_id_transform_pairs, fn {id, _} -> id end)
          |> Enum.reduce(errors_by_id, fn id, by_id -> Map.put(by_id, id, e) end)

        {model_repository, errors_by_id}
    end
  end

  defp index_parsing_errors(parsed_model_pairs) do
    Enum.reduce(parsed_model_pairs, %{}, fn {r, parsed_model_result}, by_id ->
      case parsed_model_result do
        {:ok, _} -> by_id
        {:error, e} -> Map.put(by_id, r.id, e)
      end
    end)
  end

  # Given a list of tuples of revision and parsed model results, create a
  # map of transformation operation keys to a list of tuples containing revision ids and a transformer.
  #
  # An example of the return value:
  #
  # %{
  #   shuffle: [{23, %Transformer{...}}, {36, %Transformer{...}}],
  #   variable_substitution: [{23, %Transformer{...}}]
  # }
  #
  defp group_by_operation(revision_operation_pairs) do
    Enum.reduce(revision_operation_pairs, %{}, fn {r, parsed_model_result}, all ->
      case parsed_model_result do
        {:ok, parsed_model} ->
          Enum.reduce(parsed_model.transformations, all, fn t, by_operation ->
            Map.put(by_operation, t.operation, [
              {r.id, t} | Map.get(by_operation, t.operation, [])
            ])
          end)

        _ ->
          all
      end
    end)
  end
end
