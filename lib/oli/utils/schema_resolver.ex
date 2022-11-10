defmodule Oli.Utils.SchemaResolver do
  require Logger

  @schema_versions %{
    "activity-bank-selection.schema.json" => "0.1.0",
    "activity-content.schema.json" => "0.1.0",
    "activity-reference.schema.json" => "0.1.0",
    "activity-sequence.schema.json" => "0.1.0",
    "activity.schema.json" => "0.1.0",
    "adaptive-activity-content.schema.json" => "0.1.0",
    "adaptive-activity.schema.json" => "0.1.0",
    "content-alternatives.schema.json" => "0.1.0",
    "content-block.schema.json" => "0.1.0",
    "content-break.schema.json" => "0.1.0",
    "content-element.schema.json" => "0.1.0",
    "content-group.schema.json" => "0.1.0",
    "content-survey.schema.json" => "0.1.0",
    "elements.schema.json" => "0.1.0",
    "page-content-adaptive.schema.json" => "0.1.0",
    "page-content-basic.schema.json" => "0.1.0",
    "page-content.schema.json" => "0.1.0",
    "page.schema.json" => "0.1.0",
    "purpose-type.schema.json" => "0.1.0",
    "resource.schema.json" => "0.1.0",
    "selection.schema.json" => "0.1.0"
  }

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

  def all() do
    @schemas
  end

  def get(name) do
    @schemas
    |> Enum.find(fn s -> s.name == name end)
  end

  def resolve(name) do
    @schemas
    |> Enum.find(fn s -> s.name == name end)
    |> Map.get(:schema)
    |> ExJsonSchema.Schema.resolve()
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
