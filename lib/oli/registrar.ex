defmodule Oli.Registrar do
  alias Oli.Activities
  alias Oli.Activities.Manifest
  alias Oli.PartComponents
  alias Oli.PartComponents.Manifest, as: PartComponentsManifest

  def register_local_activities(%MapSet{} = global \\ MapSet.new()) do
    Application.fetch_env!(:oli, :local_activity_manifests)
    |> Enum.map(fn body ->
      case Jason.decode(body) do
        {:ok, json} -> json
      end
    end)
    |> Enum.map(&Manifest.parse/1)
    |> Enum.filter(fn {:ok, m} ->
      # filter out any activities that have activityRegistration set to false
      m.activityRegistration
    end)
    |> Enum.map(fn {:ok, m} ->
      m =
        if(MapSet.member?(global, m.id)) do
          Map.merge(m, %{global: true})
        else
          m
        end

      Activities.register_activity(m)
    end)
  end

  def register_local_part_components(%MapSet{} = global \\ MapSet.new()) do
    Application.fetch_env!(:oli, :local_part_component_manifests)
    |> Enum.map(fn body ->
      case Jason.decode(body) do
        {:ok, json} -> json
      end
    end)
    |> Enum.map(&PartComponentsManifest.parse/1)
    |> Enum.map(fn m ->
      m =
        if(MapSet.member?(global, m.id)) do
          Map.merge(m, %{global: true})
        else
          m
        end

      PartComponents.register_part_component(m)
    end)
  end
end
