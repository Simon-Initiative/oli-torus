defmodule Oli.Interactives do
  @moduledoc """
  Starts prototype Interactive authoring sessions in OpenAI-hosted workspaces.

  Provides the hosted workspace recipe used by durable authoring builds and the
  standalone session task. Generation credentials remain outside the sandbox.
  """

  alias Oli.Interactives.{AgentsClient, Prompts}

  @doc """
  Creates a hosted authoring session for `prompt`, returning before provisioning completes.

  Options include `:model` (default `INTERACTIVES_MODEL` or `gpt-6-astra`) and the
  `Oli.Interactives.AgentsClient` request options. Only `OPENAI_API_KEY` is needed for hosted
  sessions; an executor credential is for self-hosted execution and is not forwarded.
  Both authoring skills and their shared references are installed under `/workspace/.agents/skills`.
  """
  @spec start_session(String.t(), keyword()) :: AgentsClient.result()
  def start_session(prompt, opts \\ []) do
    case is_binary(prompt) and String.trim(prompt) != "" do
      true -> AgentsClient.start_session(session_request(prompt, opts), opts)
      false -> {:error, %{kind: :configuration, message: "An authoring prompt is required."}}
    end
  end

  @doc "Builds the hosted workspace recipe without making a provider request or reading credentials."
  @spec session_request(String.t(), keyword()) :: map()
  def session_request(prompt, opts \\ []) do
    %{
      "agent" =>
        Map.merge(
          %{
            "model" =>
              Keyword.get(opts, :model, System.get_env("INTERACTIVES_MODEL", "gpt-6-astra")),
            "instructions" => Keyword.get(opts, :instructions, Prompts.instructions(:build))
          },
          Keyword.get(opts, :agent_options, %{})
        ),
      "input" => prompt,
      "environment" => %{
        "type" => "openai_hosted",
        "container_size" => "medium",
        "network" => %{"access" => "enabled"},
        "files" =>
          [
            inline_file("workspace/package.json", "/workspace/package.json"),
            inline_file("workspace/verify.cjs", "/workspace/torus-tools/verify.cjs"),
            inline_file("workspace/torus.js", "/workspace/torus-tools/torus.js"),
            inline_file(
              "skills/references/delivery-api.md",
              "/workspace/torus-tools/DELIVERY_API.md"
            )
          ] ++
            skill_files() ++
            Enum.map(Keyword.get(opts, :app_files, %{}), fn {path, data} ->
              %{
                "type" => "inline",
                "path" => "/workspace/app/#{path}",
                "data" => Base.encode64(data)
              }
            end),
        "setup_commands" => [
          %{"command" => "mkdir -p /workspace/app /workspace/outputs"},
          %{"command" => "npm install --no-audit --no-fund"},
          %{
            "command" =>
              "./node_modules/.bin/playwright install --with-deps --only-shell chromium"
          },
          %{"command" => "node /workspace/torus-tools/verify.cjs"}
        ]
      }
    }
  end

  defp skill_files do
    root = Application.app_dir(:oli, "priv/interactives/skills")

    root
    |> Path.join("**/*.md")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(fn file ->
      relative = Path.relative_to(file, root)
      inline_file("skills/#{relative}", "/workspace/.agents/skills/#{relative}")
    end)
  end

  defp inline_file(filename, destination) do
    data =
      :oli
      |> Application.app_dir("priv/interactives/#{filename}")
      |> File.read!()
      |> Base.encode64()

    %{"type" => "inline", "path" => destination, "data" => data}
  end
end
