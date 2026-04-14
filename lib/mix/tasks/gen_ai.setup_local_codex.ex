defmodule Mix.Tasks.GenAi.SetupLocalCodex do
  @moduledoc """
  Configure a local OpenAI-compatible Codex proxy for a GenAI feature.

  ## Examples

      mix gen_ai.setup_local_codex
      mix gen_ai.setup_local_codex --url http://localhost:4001 --model codex-proxy
      mix gen_ai.setup_local_codex --section-id 123
      mix gen_ai.setup_local_codex --feature instructor_dashboard_recommendation

  After running one of the commands above, start the local Codex proxy:

      node scripts/dev/codex_openai_proxy.mjs
  """

  use Mix.Task

  alias Oli.GenAI.Dev.LocalCodex

  @shortdoc "Point a GenAI feature at a local Codex proxy"

  @switches [
    api_key: :string,
    feature: :string,
    model: :string,
    model_name: :string,
    section_id: :integer,
    service_name: :string,
    url: :string
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    args
    |> parse_args()
    |> LocalCodex.setup()
    |> case do
      {:ok, %{registered_model: model, service_config: service, feature_config: feature_config}} ->
        Mix.shell().info("""
        Local Codex proxy configured.
        Registered model: #{model.name} (#{model.url_template})
        Service config: #{service.name}
        Feature config: #{feature_config.feature} / section_id=#{inspect(feature_config.section_id)}
        """)

      {:error, changeset} ->
        Mix.raise("Failed to configure local Codex proxy: #{inspect(changeset.errors)}")
    end
  end

  defp parse_args(args) do
    {opts, _rest, invalid} = OptionParser.parse(args, strict: @switches)

    case invalid do
      [] ->
        Enum.into(opts, %{})

      _ ->
        Mix.raise("Invalid options: #{inspect(invalid)}")
    end
  end
end
