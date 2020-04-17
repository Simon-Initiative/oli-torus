defmodule Oli.Registrar do

  alias Oli.Authoring.Activities
  alias Oli.Activities.Manifest

  def register_local_activities() do
    read_local_manifests()
      |> Enum.map(fn m -> Activities.register_activity(m) end)
  end

  defp read_local_manifests() do
    Path.wildcard(File.cwd! <> "/assets/src/components/activities/*/manifest.json")
      |> Enum.map(&read_manifest/1)
      |> Enum.map(&Manifest.parse/1)
  end

  defp read_manifest(filename) do
    with {:ok, body} <- File.read(filename),
          {:ok, json} <- Jason.decode(body), do: json
  end

end
