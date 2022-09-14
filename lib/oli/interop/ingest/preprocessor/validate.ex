defmodule Oli.Interop.Ingest.Preprocessor.Validate do
  alias Oli.Interop.Ingest.State
  alias Oli.Utils.SchemaResolver

  def process(%State{} = state) do
    state
    |> State.notify_step_start(:validate_activities, fn s ->
      Enum.count(s.activities)
    end)
    |> validate_json(:activities, "activity.schema.json")
    |> State.notify_step_start(:validate_pages, fn s ->
      Enum.count(s.pages)
    end)
    |> validate_json(:pages, "page-content.schema.json", "content")
  end

  defp validate_json(%State{errors: errors} = state, key, schema_ref, attr \\ nil) do
    schema = SchemaResolver.schema(schema_ref)

    errors =
      Map.get(state, key)
      |> Enum.reduce(errors, fn {id, resource}, all_errors ->
        State.notify_step_progress(state, "#{id}.json")

        content =
          case attr do
            nil -> resource
            attr -> Map.get(resource, attr)
          end

        case ExJsonSchema.Validator.validate(schema, content) do
          :ok ->
            all_errors

          {:error, errors} ->
            Enum.map(errors, fn {e, _} ->
              "Resource id [#{id}] failed JSON validation with error [#{e}]"
            end) ++ all_errors
        end
      end)

    %{state | errors: errors}
  end
end
