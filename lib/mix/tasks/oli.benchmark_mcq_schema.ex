defmodule Mix.Tasks.Oli.BenchmarkMcqSchema do
  @shortdoc "Measure cold build and cached MCQ JSON Schema validation"
  @moduledoc """
  Measures the shared MCQ schema graph without starting the Torus application.

      mix oli.benchmark_mcq_schema path/to/model.json --iterations 1000

  Accepts an authored MCQ model or an Activity export's `content`. JSON decoding
  is outside the timed region. Each warm measurement includes explicit activity
  schema selection, cache lookup, validation and (for invalid input) error
  formatting. Reports elapsed time and current-process reductions, not a claim
  of production throughput. No files, database records or model values change.
  """
  use Mix.Task

  alias Oli.Utils.{JSONValidation, SchemaResolver}
  alias Oli.Validation

  @impl Mix.Task
  def run(args) do
    {opts, paths} = OptionParser.parse!(args, strict: [iterations: :integer])
    count = Keyword.get(opts, :iterations, 1000)

    path =
      case paths do
        [path] when count > 0 -> path
        _ -> Mix.raise("Provide one model JSON file and a positive --iterations count")
      end

    Mix.Task.run("app.config")
    decoded = path |> File.read!() |> Jason.decode!()

    model =
      case decoded do
        %{"type" => "Activity", "content" => content} -> content
        content -> content
      end

    schema = SchemaResolver.get("multiple-choice.schema.json").schema

    {build_us, root} =
      :timer.tc(fn -> JSONValidation.build!(schema, cache_revision: make_ref()) end)

    case JSONValidation.validate(root, model) do
      :ok -> :ok
      {:error, _} -> Mix.raise("Input does not satisfy the MCQ schema")
    end

    # Warm the named graph separately; this is the API used by application callers.
    :ok = Validation.validate_activity_schema("oli_multiple_choice", model)

    bad_element = %{"type" => "p", "children" => [%{}]}

    invalid =
      update_in(model, ["stem", "content"], fn
        content when is_list(content) -> content ++ [bad_element]
        %{"model" => _} = legacy -> Map.update!(legacy, "model", &(&1 ++ [bad_element]))
      end)

    results = %{
      iterations: count,
      model_bytes: byte_size(Jason.encode!(model)),
      cold_build_us: build_us,
      valid:
        measure(count, fn ->
          :ok = Validation.validate_activity_schema("oli_multiple_choice", model)
        end),
      invalid:
        measure(count, fn ->
          {:error, [_ | _]} = Validation.validate_activity_schema("oli_multiple_choice", invalid)
        end)
    }

    Mix.shell().info(Jason.encode!(results, pretty: true))
  end

  defp measure(count, fun) do
    {:reductions, before_count} = Process.info(self(), :reductions)
    {elapsed, _} = :timer.tc(fn -> Enum.each(1..count, fn _ -> fun.() end) end)
    {:reductions, after_count} = Process.info(self(), :reductions)

    %{
      total_us: elapsed,
      mean_us: elapsed / count,
      reductions_per_validation: (after_count - before_count) / count
    }
  end
end
