defmodule Oli.Utils.SchemaResolver do
  require Logger

  @schema_versions %{
    "activity-bank-selection.schema.json" => "0.1.0",
    "activity-components.schema.json" => "0.1.0",
    "activity-content.schema.json" => "0.1.0",
    "activity-reference.schema.json" => "0.1.0",
    "activity-sequence.schema.json" => "0.1.0",
    "activity.schema.json" => "0.1.0",
    "adaptive-activity-content.schema.json" => "0.1.0",
    "adaptive-activity.schema.json" => "0.1.0",
    "adaptive.schema.json" => "0.1.0",
    "audience.schema.json" => "0.1.0",
    "content-alternatives.schema.json" => "0.1.0",
    "content-block.schema.json" => "0.1.0",
    "content-break.schema.json" => "0.1.0",
    "content-element.schema.json" => "0.1.0",
    "content-group.schema.json" => "0.1.0",
    "content-report.schema.json" => "0.1.0",
    "content-survey.schema.json" => "0.1.0",
    "elements.schema.json" => "0.1.0",
    "ordering.schema.json" => "0.1.0",
    "ordering-activity.schema.json" => "0.1.0",
    "check-all-that-apply.schema.json" => "0.1.0",
    "check-all-that-apply-activity.schema.json" => "0.1.0",
    "likert.schema.json" => "0.1.0",
    "likert-activity.schema.json" => "0.1.0",
    "file-upload.schema.json" => "0.1.0",
    "file-upload-activity.schema.json" => "0.1.0",
    "short-answer.schema.json" => "0.1.0",
    "short-answer-activity.schema.json" => "0.1.0",
    "short-answer-config.schema.json" => "0.1.0",
    "multiple-choice-activity.schema.json" => "0.1.0",
    "multiple-choice.schema.json" => "0.1.0",
    "multi-input.schema.json" => "0.1.0",
    "directed-discussion.schema.json" => "0.1.0",
    "image-coding.schema.json" => "0.1.0",
    "custom-dnd.schema.json" => "0.1.0",
    "custom-dnd-activity.schema.json" => "0.1.0",
    "response-multi.schema.json" => "0.1.0",
    "image-hotspot.schema.json" => "0.1.0",
    "image-hotspot-activity.schema.json" => "0.1.0",
    "oli-embedded.schema.json" => "0.1.0",
    "oli-embedded-activity.schema.json" => "0.1.0",
    "lti-external-tool.schema.json" => "0.1.0",
    "lti-external-tool-activity.schema.json" => "0.1.0",
    "logic-lab.schema.json" => "0.1.0",
    "logic-lab-activity.schema.json" => "0.1.0",
    "vlab.schema.json" => "0.1.0",
    "vlab-activity.schema.json" => "0.1.0",
    "response-multi-activity.schema.json" => "0.1.0",
    "image-coding-activity.schema.json" => "0.1.0",
    "directed-discussion-activity.schema.json" => "0.1.0",
    "multi-input-activity.schema.json" => "0.1.0",
    "learning-objectives.schema.json" => "0.1.0",
    "page-content-adaptive.schema.json" => "0.1.0",
    "adaptive-page-components.schema.json" => "0.1.0",
    "adaptive-page.schema.json" => "0.1.0",
    "page-content-basic.schema.json" => "0.1.0",
    "page-content.schema.json" => "0.1.0",
    "page.schema.json" => "0.1.0",
    "purpose-type.schema.json" => "0.1.0",
    "resource.schema.json" => "0.1.0",
    "scenario.schema.json" => "0.1.0",
    "selection.schema.json" => "0.1.0"
  }

  for {name, version} <- @schema_versions do
    @external_resource Path.join([
                         :code.priv_dir(:oli),
                         "schemas",
                         "v#{String.replace(version, ".", "-")}",
                         name
                       ])
  end

  @schemas Enum.map(@schema_versions, fn {name, version} ->
             with {:ok, json} <-
                    File.read(
                      "#{:code.priv_dir(:oli)}/schemas/v#{String.replace(version, ".", "-")}/#{name}"
                    ),
                  {:ok, schema} <- Jason.decode(json) do
               %{
                 name: name,
                 version: version,
                 uri: schema["$id"],
                 schema: schema
               }
             else
               error ->
                 Logger.error("Failed to resolve schema #{name}")

                 throw(error)
             end
           end)

  @schema_revision :crypto.hash(:sha256, :erlang.term_to_binary(@schemas))

  def all() do
    @schemas
  end

  def get(name) do
    @schemas
    |> Enum.find(fn s -> s.name == name end)
  end

  @doc "Returns a cached, opaque validator for a registered schema name."
  def resolve(name) do
    @schemas
    |> Enum.find(fn s -> s.name == name end)
    |> Map.get(:schema)
    |> Oli.Utils.JSONValidation.build!(cache_revision: @schema_revision)
  end

  def resolve_uri(uri) do
    # if uri is relative (local file) or the domain is torus, fetch locally
    if !String.match?(uri, ~r/^https?:\/\//) or
         String.match?(uri, ~r/^https?:\/\/torus.oli.cmu.edu/) do
      with [schema_path] <-
             Regex.run(~r/^https?:\/\/torus.oli.cmu.edu\/(.+)/, uri, capture: :all_but_first),
           {:ok, json} <-
             File.read("#{:code.priv_dir(:oli)}/#{schema_path}"),
           {:ok, decoded} <- Jason.decode(json) do
        decoded
      else
        error ->
          Logger.error("Failed to resolve schema #{uri}")

          throw(error)
      end
    else
      HTTPoison.get!(uri).body |> Poison.decode!()
    end
  end
end
