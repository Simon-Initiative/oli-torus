defmodule Oli.Registrar do

  alias Oli.Activities
  alias Oli.Activities.Manifest

  def register_local_activities() do
    Application.fetch_env!(:oli, :local_activity_manifests)
      |> Enum.map(&read_manifest/1)
      |> Enum.map(&Manifest.parse/1)
      |> Enum.map(fn m -> Activities.register_activity(m) end)
  end

  defp read_manifest(filename) do
    with {:ok, body} <- File.read(filename),
          {:ok, json} <- Jason.decode(body), do: json
  end

end
