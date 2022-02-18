defmodule OliWeb.IngestView do
  use OliWeb, :view

  import Oli.Interop.Ingest, only: [prettify_error: 1]

  alias Oli.Utils.SchemaResolver

  def schemas() do
    Path.join([:code.priv_dir(:oli), "schemas"])
    |> File.ls!()
    |> Enum.filter(&String.match?(&1, ~r/\.schema\.json$/))
    |> Enum.map(fn uri ->
      schema = SchemaResolver.resolve(uri)

      %{
        uri: schema["$id"],
        schema: SchemaResolver.resolve(uri)
      }
    end)

  end
end
