defmodule Oli.Utils.SchemaResolver do
  @version "0-1-0"

  def resolve(url) do
    if String.starts_with?(url, "http://torus.oli.cmu.edu") do
      with schema_basename <- Path.basename(url),
           {:ok, json} <-
             File.read("#{:code.priv_dir(:oli)}/schemas/v#{@version}/#{schema_basename}"),
           {:ok, decoded} <- Jason.decode(json) do
        decoded
      end
    else
      HTTPoison.get!(url).body |> Poison.decode!()
    end
  end
end
