defmodule Mix.Tasks.Interactives.Session do
  @moduledoc """
  Exercises Interactive hosted authoring sessions without starting Phoenix or the database.

      mix interactives.session --smoke --wait
      mix interactives.session --prompt "Create a graphing exercise" --wait
      mix interactives.session --session SESSION_ID --wait
      mix interactives.session --session SESSION_ID --cancel
      mix interactives.session --session SESSION_ID --delete

  Set `OPENAI_API_KEY` in the shell. `--model` overrides `INTERACTIVES_MODEL`.
  Launching creates billable remote work. Retain the printed session ID. `--wait`
  observes the latest turn for up to `--timeout` seconds (default 900); timing out
  leaves remote work running. Inspect the same session or cancel it, then delete it
  when finished to release the sandbox. This standalone diagnostic does not persist authoring
  builds or handle completion callbacks.
  """

  use Mix.Task

  alias Oli.Interactives
  alias Oli.Interactives.AgentsClient

  @shortdoc "Launch or inspect an OpenAI-hosted Interactive prototype session"
  @switches [
    prompt: :string,
    smoke: :boolean,
    model: :string,
    session: :string,
    wait: :boolean,
    timeout: :integer,
    cancel: :boolean,
    delete: :boolean
  ]
  @smoke_prompt """
  Create a tiny client-side web experience in /workspace/app: a button that increments a
  displayed counter. Bundle its JavaScript with esbuild, serve it over loopback HTTP,
  and use Playwright Chromium to click twice and assert that the counter shows 2 and
  that there are no browser errors. Use Python zipfile to write the static deliverable
  to /workspace/outputs/interactive-smoke.zip with index.html at its root. Read the ZIP
  back to verify its entries. Include the actual results from ready.json and your
  application/browser/ZIP checks in your final response. Do not call back to Torus.
  """

  @impl Mix.Task
  def run(args) do
    {opts, rest, invalid} = OptionParser.parse(args, strict: @switches)
    validate_options!(opts, rest, invalid)
    Mix.Task.run("compile")
    {:ok, _} = Application.ensure_all_started(:httpoison)

    # This diagnostic task has no managed build record, skill targets or completion tool.
    request_opts =
      Keyword.take(opts, [:model])
      |> Keyword.put(:instructions, """
      This is a standalone Torus tooling diagnostic, not a managed authoring build.
      Follow the requested artifact and browser checks. Tooling is under /workspace/node_modules;
      setup results are in /workspace/torus-tools/ready.json. No finish_interactive tool is registered;
      leave the requested artifact under /workspace/outputs and report the actual checks performed.
      """)

    case opts[:session] do
      nil ->
        prompt =
          case opts[:smoke] do
            true -> @smoke_prompt
            _ -> opts[:prompt]
          end

        session = unwrap!(Interactives.start_session(prompt, request_opts))
        id = Map.fetch!(session, "id")
        Mix.shell().info("Session: #{id}")
        observe(id, opts)

      id ->
        cond do
          opts[:cancel] ->
            unwrap!(AgentsClient.cancel_session(id))
            Mix.shell().info("Cancellation accepted for #{id}; inspect it before deleting.")

          opts[:delete] ->
            unwrap!(AgentsClient.delete_session(id))
            Mix.shell().info("Session #{id} deleted; sandbox cleanup requested.")

          true ->
            observe(id, opts)
        end
    end
  end

  defp validate_options!(opts, rest, invalid) do
    has_session = is_binary(opts[:session]) and String.trim(opts[:session]) != ""
    has_prompt = is_binary(opts[:prompt]) and String.trim(opts[:prompt]) != ""
    smoke? = opts[:smoke] == true
    cancel? = opts[:cancel] == true
    delete? = opts[:delete] == true
    launch = has_prompt or smoke?

    valid =
      rest == [] and invalid == [] and
        Keyword.get(opts, :timeout, 900) > 0 and
        not (cancel? and delete?) and
        not (has_prompt and smoke?) and
        ((has_session and not launch) or (launch and not has_session)) and
        (has_session or not (cancel? or delete?))

    case valid do
      true ->
        :ok

      _ ->
        Mix.raise(
          "Use --prompt TEXT or --smoke to launch; use --session ID to inspect, --cancel, or --delete. See mix help interactives.session."
        )
    end
  end

  defp observe(id, opts) do
    deadline = System.monotonic_time(:second) + Keyword.get(opts, :timeout, 900)
    observe(id, opts[:wait] == true, deadline, nil)
  end

  defp observe(id, wait?, deadline, previous_status) do
    session = unwrap!(AgentsClient.get_session(id))
    turns = unwrap!(AgentsClient.latest_turn(id))
    turn = List.first(turns["data"] || []) || %{}

    environment =
      case get_in(session, ["environment", "id"]) do
        nil -> %{}
        environment_id -> unwrap!(AgentsClient.get_environment(environment_id))
      end

    status = {session["status"], environment["status"], turn["status"]}

    case status == previous_status do
      true ->
        :ok

      false ->
        Mix.shell().info(
          "Session #{id}: session=#{session["status"]}, environment=#{environment["status"]}, turn=#{turn["status"]}"
        )
    end

    cond do
      session["status"] == "failed" or environment["status"] == "failed" or
          turn["status"] in ["failed", "cancelled"] ->
        Mix.raise(
          "Session #{id} failed or was cancelled. Inspect it with the provider; retain the ID for cleanup."
        )

      session["status"] == "requires_action" ->
        Mix.raise(
          "Session #{id} requires an external action; the hosted prototype does not grant external tools."
        )

      not wait? or (turn["status"] == "completed" and environment["status"] == "connected") ->
        print_items(id)

      System.monotonic_time(:second) >= deadline ->
        Mix.raise(
          "Timed out observing #{id}. Remote work may still be running. Reuse --session #{id} --wait, or --session #{id} --cancel; do not launch a duplicate."
        )

      true ->
        Process.sleep(2_000)
        observe(id, wait?, deadline, status)
    end
  end

  defp print_items(id, after_id \\ nil) do
    page = unwrap!(AgentsClient.items_page(id, after_id))

    for %{"role" => "assistant", "content" => content} <- page["data"] || [],
        %{"type" => "output_text", "text" => text} <- content do
      Mix.shell().info(text)
    end

    case {page["has_more"], page["last_id"]} do
      {true, cursor} when is_binary(cursor) and cursor != after_id -> print_items(id, cursor)
      _ -> :ok
    end
  end

  defp unwrap!({:ok, data}), do: data

  defp unwrap!({:error, error}) do
    uncertainty =
      case error[:creation_uncertain] do
        true -> " Remote state is uncertain; inspect the provider before retrying."
        _ -> ""
      end

    Mix.raise(error.message <> uncertainty)
  end
end
