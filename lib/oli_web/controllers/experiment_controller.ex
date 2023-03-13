defmodule OliWeb.ExperimentController do
  use OliWeb, :controller

  alias Oli.Authoring.Course.Project

  require Logger

  def experiment_download(conn, %{"project_id" => project_slug}) do
    case Oli.Authoring.Course.get_project_by_slug(project_slug) do
      nil -> error(conn, 404, "Project not found")
      project -> do_experiment_download(conn, project)
    end
  end

  def segment_download(conn, %{"project_id" => project_slug}) do
    case Oli.Authoring.Course.get_project_by_slug(project_slug) do
      nil -> error(conn, 404, "Project not found")
      project -> do_segment_download(conn, project)
    end
  end

  defp do_experiment_download(conn, %Project{slug: slug} = project) do

    encoded_experiment = Oli.Delivery.Experiments.ExperimentBuilder.build(project)
    |> Poison.encode!()

    conn
    |> send_download({:binary, encoded_experiment},
      filename: "experiment_#{slug}.json"
    )
  end

  defp do_segment_download(conn, %Project{slug: slug} = project) do

    encoded_segment = Oli.Delivery.Experiments.SegmentBuilder.build(project)
    |> Poison.encode!()

    conn
    |> send_download({:binary, encoded_segment},
      filename: "segment_#{slug}.json"
    )

  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end

end
