defmodule Mix.Tasks.Oli.AuditBasicPages do
  @shortdoc "Read-only compatibility audit of Basic Page JSON"
  @moduledoc """
  Audits Basic Page content without changing files or database records.

      mix oli.audit_basic_pages 'test/oli/interop/digest/*.json'
      mix oli.audit_basic_pages --database --max-errors 20

  Files may contain a Page export or a page-content object. Other resource types
  and adaptive pages are skipped. Database mode streams all page revisions,
  including historical and deleted revisions. Legacy page envelopes are checked
  after applying the existing in-memory ContentMigrator; nothing is persisted.

  Output is JSON containing counts and a bounded set of identifiers and failing
  JSON Pointer paths. Submitted content and validation messages are not printed.
  Use `--fail-on-invalid` to return an error when invalid pages are found.
  """
  use Mix.Task

  import Ecto.Query

  alias Oli.Resources.{ContentMigrator, ResourceType, Revision}
  alias Oli.Utils.{JSONValidation, SchemaResolver}

  @impl Mix.Task
  def run(args) do
    {opts, paths} =
      OptionParser.parse!(args,
        strict: [database: :boolean, max_errors: :integer, fail_on_invalid: :boolean]
      )

    limit = Keyword.get(opts, :max_errors, 20)

    case limit >= 0 and (paths != [] or opts[:database] == true) do
      true -> :ok
      false -> Mix.raise("Provide JSON paths or --database, and a nonnegative --max-errors")
    end

    Mix.Task.run("app.config")
    root = SchemaResolver.resolve("page-content-basic.schema.json")

    initial = %{
      checked: 0,
      valid: 0,
      invalid: 0,
      skipped: 0,
      legacy_envelopes: 0,
      samples: [],
      database_revisions: 0
    }

    files = paths |> Enum.flat_map(&Path.wildcard/1) |> Enum.uniq() |> Enum.sort()

    case paths != [] and files == [] do
      true -> Mix.raise("No JSON files matched the provided paths")
      false -> :ok
    end

    summary =
      Enum.reduce(files, initial, fn path, summary ->
        case path |> File.read!() |> Jason.decode!() do
          %{"type" => "Page"} = page ->
            audit(Map.get(page, "content"), path, summary, root, limit)

          %{"type" => _} ->
            Map.update!(summary, :skipped, &(&1 + 1))

          %{"model" => _} = content ->
            audit(content, path, summary, root, limit)

          _ ->
            Map.update!(summary, :skipped, &(&1 + 1))
        end
      end)

    summary =
      case opts[:database] do
        true ->
          start_repo()
          page_type = ResourceType.id_for_page()

          query =
            from(r in Revision,
              where: r.resource_type_id == ^page_type,
              select: {r.id, r.content}
            )

          {:ok, result} =
            Oli.Repo.transaction(
              fn ->
                Oli.Repo.query!("SET TRANSACTION READ ONLY", [], log: false)

                query
                |> Oli.Repo.stream()
                |> Enum.reduce(summary, fn {id, content}, acc ->
                  audit(
                    content,
                    id,
                    %{acc | database_revisions: acc.database_revisions + 1},
                    root,
                    limit
                  )
                end)
              end,
              timeout: :infinity
            )

          result

        _ ->
          summary
      end

    Mix.shell().info(
      Jason.encode!(%{summary | samples: Enum.reverse(summary.samples)}, pretty: true)
    )

    case opts[:fail_on_invalid] == true and summary.invalid > 0 do
      true -> Mix.raise("#{summary.invalid} Basic Page revisions failed validation")
      false -> :ok
    end
  end

  # Start only the database dependencies, not the application and its background jobs.
  defp start_repo do
    case Process.whereis(Oli.Repo) do
      nil ->
        {:ok, _} = Application.ensure_all_started(:ecto_sql)
        {:ok, _} = Application.ensure_all_started(:postgrex)
        {:ok, _} = Oli.Repo.start_link()
        :ok

      _pid ->
        :ok
    end
  end

  defp audit(%{"advancedAuthoring" => true}, _id, summary, _root, _limit),
    do: Map.update!(summary, :skipped, &(&1 + 1))

  defp audit(content, id, summary, root, limit) do
    {content, legacy} =
      case content do
        %{"model" => model} when is_list(model) ->
          {ContentMigrator.migrate(content, :page, to: :latest),
           not Map.has_key?(content, "version")}

        _ ->
          {content, false}
      end

    legacy_count =
      case legacy do
        true -> 1
        false -> 0
      end

    summary = %{
      summary
      | checked: summary.checked + 1,
        legacy_envelopes: summary.legacy_envelopes + legacy_count
    }

    case JSONValidation.validate(root, content) do
      :ok ->
        %{summary | valid: summary.valid + 1}

      {:error, errors} ->
        samples =
          case length(summary.samples) < limit do
            true ->
              [
                %{id: id, paths: errors |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> Enum.take(20)}
                | summary.samples
              ]

            false ->
              summary.samples
          end

        %{summary | invalid: summary.invalid + 1, samples: samples}
    end
  end
end
