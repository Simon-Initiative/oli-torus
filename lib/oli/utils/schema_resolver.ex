defmodule Oli.Utils.SchemaResolver do
  require Logger

  @current_version "v0-1-0"

  @schemas "priv/schemas/#{@current_version}"
    |> File.ls!()
    |> Enum.filter(&String.match?(&1, ~r/\.schema\.json$/))
    |> Enum.map(fn name ->
      with {:ok, json} <- File.read("#{:code.priv_dir(:oli)}/schemas/#{@current_version}/#{name}"),
           {:ok, schema} <- Jason.decode(json) do
        %{
          name: name,
          uri: schema["$id"],
          schema: schema
        }

      else
        error ->
          Logger.error("Failed to resolve schema #{name}")

          throw error
      end
    end)

  def current_version() do
    @current_version
  end

  def schemas() do
    @schemas
  end

  def schema(name) do
    @schemas
    |> Enum.find(fn s -> s.name == name end)
    |> Map.get(:schema)
    |> ExJsonSchema.Schema.resolve()
  end

  def resolve(uri) do
    # if uri is relative (local file) or the domain is torus, fetch locally
    if !String.match?(uri, ~r/^https?:\/\//) or
         String.starts_with?(uri, "http://torus.oli.cmu.edu") do
      with schema_basename <- Path.basename(uri),
           {:ok, json} <-
             File.read("#{:code.priv_dir(:oli)}/schemas/#{@current_version}/#{schema_basename}"),
           {:ok, decoded} <- Jason.decode(json) do
        decoded

      else
        error ->
          Logger.error("Failed to resolve schema #{uri}")

          throw error
      end
    else
      HTTPoison.get!(uri).body |> Poison.decode!()
    end
  end

end
