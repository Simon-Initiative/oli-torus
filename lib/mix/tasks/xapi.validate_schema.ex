defmodule Mix.Tasks.Xapi.ValidateSchema do
  @moduledoc """
  Validate JSONL xAPI statement files against the Torus xAPI reference schema.

  Usage:

      mix xapi.validate_schema path/to/file.jsonl
      mix xapi.validate_schema path/to/dir
      mix xapi.validate_schema "tmp/xapi/**/*.jsonl"

  Options:

      --schema PATH       Override the schema path
      --max-errors N      Limit stored error rows per file (default: 20)
      --trace             Print per-file results instead of dot progress
  """

  use Mix.Task

  alias Oli.Analytics.XAPI.SchemaValidator

  @shortdoc "Validate xAPI JSONL files against the Torus xAPI schema"

  @impl Mix.Task
  def run(args) do
    {opts, paths, invalid} =
      OptionParser.parse(args,
        strict: [schema: :string, max_errors: :integer, trace: :boolean]
      )

    case {invalid, paths} do
      {[_ | _], _} ->
        Mix.raise("invalid options: #{inspect(invalid)}")

      {[], []} ->
        Mix.raise("expected at least one file, directory, or glob")

      {[], _} ->
        validate(paths, opts)
    end
  end

  defp validate(paths, opts) do
    trace? = Keyword.get(opts, :trace, false)
    progress_callback = build_progress_callback(trace?)

    case SchemaValidator.validate_paths(
           paths,
           Keyword.put(opts, :on_file_result, progress_callback)
         ) do
      {:ok, summary} ->
        if not trace? do
          Mix.shell().info("")
        end

        print_summary(summary)

        if summary.error_count > 0 do
          exit({:shutdown, 1})
        end

      {:error, message} ->
        Mix.raise(message)
    end
  end

  defp build_progress_callback(true) do
    &print_file_result/1
  end

  defp build_progress_callback(false) do
    fn file ->
      case file.invalid_json_lines + file.schema_mismatch_lines do
        0 ->
          IO.write(".")

        _ ->
          Mix.shell().info("")
          print_file_result(file)
      end
    end
  end

  defp print_file_result(file) do
    Mix.shell().info(file.path)
    Mix.shell().info("  lines: #{file.total_lines}")
    Mix.shell().info("  valid: #{file.valid_lines}")
    Mix.shell().info("  invalid_json: #{file.invalid_json_lines}")
    Mix.shell().info("  schema_mismatch: #{file.schema_mismatch_lines}")

    Enum.each(file.errors, fn error ->
      Mix.shell().info("  line #{error.line} [#{error.classification}]: #{error.message}")

      Mix.shell().info("    preview: #{error.preview}")

      Enum.each(error.details, fn detail ->
        detail_line =
          case detail.path do
            "" -> "    detail: #{detail.message}"
            path -> "    detail #{path}: #{detail.message}"
          end

        Mix.shell().info(detail_line)
      end)
    end)

    Mix.shell().info("")
  end

  defp print_summary(summary) do
    Mix.shell().info("---------------------------")
    Mix.shell().info("files processed: #{summary.file_count}")
    Mix.shell().info("lines processed: #{summary.total_lines}")
    Mix.shell().info("valid lines: #{summary.valid_lines}")
    Mix.shell().info("invalid json lines: #{summary.invalid_json_lines}")
    Mix.shell().info("schema mismatch lines: #{summary.schema_mismatch_lines}")
    Mix.shell().info("total failing lines: #{summary.error_count}")

    case summary.error_count do
      0 -> Mix.shell().info("result: success")
      _ -> Mix.shell().info("result: failure")
    end
  end
end
