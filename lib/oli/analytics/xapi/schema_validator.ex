defmodule Oli.Analytics.XAPI.SchemaValidator do
  @moduledoc """
  Validates JSONL xAPI statement files against the Torus xAPI reference schema.
  """

  @default_schema_path "priv/schemas/xapi/v0-0-1/statement.schema.json"

  @type error_entry :: %{
          path: String.t(),
          line: pos_integer(),
          classification: :invalid_json | :schema_mismatch,
          message: String.t(),
          preview: String.t(),
          details: [map()]
        }

  @type file_summary :: %{
          path: String.t(),
          total_lines: non_neg_integer(),
          valid_lines: non_neg_integer(),
          invalid_json_lines: non_neg_integer(),
          schema_mismatch_lines: non_neg_integer(),
          errors: [error_entry()]
        }

  @type summary :: %{
          files: [file_summary()],
          file_count: non_neg_integer(),
          total_lines: non_neg_integer(),
          valid_lines: non_neg_integer(),
          invalid_json_lines: non_neg_integer(),
          schema_mismatch_lines: non_neg_integer(),
          error_count: non_neg_integer()
        }

  @spec validate_paths([String.t()], keyword()) :: {:ok, summary()} | {:error, String.t()}
  def validate_paths(paths, opts \\ []) when is_list(paths) do
    with {:ok, files} <- expand_paths(paths),
         {:ok, schema} <- load_schema(opts) do
      callback = Keyword.get(opts, :on_file_result)

      files
      |> Enum.map(fn path ->
        result = validate_file(path, schema, opts)

        if is_function(callback, 1) do
          callback.(result)
        end

        result
      end)
      |> summarize()
      |> then(&{:ok, &1})
    end
  end

  @spec default_schema_path() :: String.t()
  def default_schema_path, do: @default_schema_path

  defp expand_paths(paths) do
    files =
      paths
      |> Enum.flat_map(&expand_path/1)
      |> Enum.uniq()
      |> Enum.sort()

    case files do
      [] -> {:error, "no JSONL files found"}
      _ -> {:ok, files}
    end
  end

  defp expand_path(path) do
    cond do
      File.regular?(path) and jsonl_file?(path) ->
        [path]

      File.dir?(path) ->
        path
        |> Path.join("**/*.jsonl")
        |> Path.wildcard()
        |> Enum.filter(&File.regular?/1)

      String.contains?(path, ["*", "?", "["]) ->
        path
        |> Path.wildcard()
        |> Enum.filter(&(File.regular?(&1) and jsonl_file?(&1)))

      true ->
        []
    end
  end

  defp jsonl_file?(path), do: String.ends_with?(String.downcase(path), ".jsonl")

  defp load_schema(opts) do
    schema_path = Keyword.get(opts, :schema_path, @default_schema_path)

    with {:ok, raw} <- File.read(schema_path),
         {:ok, decoded} <- Jason.decode(raw) do
      {:ok, ExJsonSchema.Schema.resolve(decoded)}
    else
      {:error, reason} when is_atom(reason) ->
        {:error, "failed to read schema #{schema_path}: #{inspect(reason)}"}

      {:error, %Jason.DecodeError{} = error} ->
        {:error, "failed to decode schema #{schema_path}: #{Exception.message(error)}"}
    end
  end

  defp validate_file(path, schema, opts) do
    max_errors = Keyword.get(opts, :max_errors, 20)

    {line_count, valid_count, invalid_json_count, schema_mismatch_count, errors} =
      path
      |> File.stream!([], :line)
      |> Enum.with_index(1)
      |> Enum.reduce({0, 0, 0, 0, []}, fn {line, line_number},
                                          {total, valid, invalid_json, mismatch, errors} ->
        trimmed = String.trim_trailing(line, "\n") |> String.trim_trailing("\r")

        case Jason.decode(trimmed) do
          {:ok, decoded} ->
            case ExJsonSchema.Validator.validate(schema, decoded) do
              :ok ->
                {total + 1, valid + 1, invalid_json, mismatch, errors}

              {:error, validation_errors} ->
                updated_errors =
                  maybe_append_error(errors, max_errors, %{
                    path: path,
                    line: line_number,
                    classification: :schema_mismatch,
                    message: format_schema_errors(validation_errors),
                    preview: line_preview(trimmed),
                    details: format_schema_error_details(validation_errors)
                  })

                {total + 1, valid, invalid_json, mismatch + 1, updated_errors}
            end

          {:error, error} ->
            updated_errors =
              maybe_append_error(errors, max_errors, %{
                path: path,
                line: line_number,
                classification: :invalid_json,
                message: Exception.message(error),
                preview: line_preview(trimmed),
                details: []
              })

            {total + 1, valid, invalid_json + 1, mismatch, updated_errors}
        end
      end)

    %{
      path: path,
      total_lines: line_count,
      valid_lines: valid_count,
      invalid_json_lines: invalid_json_count,
      schema_mismatch_lines: schema_mismatch_count,
      errors: errors
    }
  end

  defp maybe_append_error(errors, max_errors, error) when length(errors) < max_errors,
    do: errors ++ [error]

  defp maybe_append_error(errors, _max_errors, _error), do: errors

  defp format_schema_errors(errors) when is_list(errors) do
    errors
    |> Enum.map(&format_schema_error/1)
    |> Enum.join("; ")
  end

  defp format_schema_error_details(errors) when is_list(errors) do
    Enum.map(errors, fn error ->
      case error do
        {message, path} ->
          %{path: to_string(path), message: to_string(message)}

        %{__exception__: true} = exception ->
          %{path: "", message: Exception.message(exception)}

        message when is_binary(message) ->
          %{path: "", message: message}

        other ->
          %{path: "", message: inspect(other)}
      end
    end)
  end

  defp format_schema_error(%{__exception__: true} = error), do: Exception.message(error)
  defp format_schema_error({message, path}), do: "#{path}: #{message}"
  defp format_schema_error(error) when is_binary(error), do: error
  defp format_schema_error(error), do: inspect(error)

  defp line_preview(line) when is_binary(line) do
    line
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
    |> String.slice(0, 300)
  end

  defp summarize(files) do
    Enum.reduce(files, initial_summary(files), fn file, acc ->
      %{
        acc
        | total_lines: acc.total_lines + file.total_lines,
          valid_lines: acc.valid_lines + file.valid_lines,
          invalid_json_lines: acc.invalid_json_lines + file.invalid_json_lines,
          schema_mismatch_lines: acc.schema_mismatch_lines + file.schema_mismatch_lines,
          error_count: acc.error_count + file.invalid_json_lines + file.schema_mismatch_lines
      }
    end)
  end

  defp initial_summary(files) do
    %{
      files: files,
      file_count: length(files),
      total_lines: 0,
      valid_lines: 0,
      invalid_json_lines: 0,
      schema_mismatch_lines: 0,
      error_count: 0
    }
  end
end
