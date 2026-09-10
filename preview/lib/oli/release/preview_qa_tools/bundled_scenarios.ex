defmodule Oli.Release.PreviewQATools.BundledScenarios do
  @moduledoc "Registry for immutable scenarios packaged in preview releases."

  @manifest "preview_qa_tools/scenarios/manifest.json"

  def list do
    @manifest
    |> priv_path()
    |> File.read!()
    |> Jason.decode!()
    |> Enum.map(&Map.take(&1, ["id", "description", "version", "digest"]))
  end

  def fetch(id) when is_binary(id) do
    case Enum.find(list(), &(&1["id"] == id)) do
      nil -> {:error, :unknown_scenario}
      metadata -> verify_asset(metadata, priv_path("preview_qa_tools/scenarios/#{id}.yaml"))
    end
  end

  defp verify_asset(%{"digest" => "sha256:" <> expected} = metadata, path) do
    with {:ok, body} <- File.read(path),
         actual <- :crypto.hash(:sha256, body) |> Base.encode16(case: :lower),
         true <- Plug.Crypto.secure_compare(actual, expected) do
      {:ok, metadata, path}
    else
      _ -> {:error, :invalid_asset}
    end
  end

  defp verify_asset(_metadata, _path), do: {:error, :invalid_asset}

  defp priv_path(path), do: Application.app_dir(:oli, "priv/#{path}")
end
