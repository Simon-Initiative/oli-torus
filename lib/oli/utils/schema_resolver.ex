defmodule Oli.Utils.SchemaResolver do
  @current_version "v0-1-0"

  @schemas "priv/schemas/#{@current_version}"
    |> File.ls!()
    |> Enum.filter(&String.match?(&1, ~r/\.schema\.json$/))
    |> Enum.map(fn name ->
      with {:ok, json} <-
              File.read("#{:code.priv_dir(:oli)}/schemas/#{@current_version}/#{name}"),
           {:ok, schema} <- Jason.decode(json) do
        %{
          name: name,
          uri: schema["$id"],
          schema: schema
        }
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
      end
    else
      HTTPoison.get!(uri).body |> Poison.decode!()
    end
  end

end
