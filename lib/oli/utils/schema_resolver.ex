defmodule Oli.Utils.SchemaResolver do
  def resolve(url) do
    with schema_basename <- Path.basename(url),
         {:ok, json} <- File.read("#{:code.priv_dir(:oli)}/schemas/#{schema_basename}"),
         {:ok, decoded} <- Jason.decode(json) do
      decoded
    end
  end
end
