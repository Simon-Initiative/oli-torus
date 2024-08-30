defmodule Oli.Delivery.Experiments do
  @moduledoc """
  Interface to Upgrade-powered experiments.
  """

  require Logger
  import Oli.HTTP
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section

  @doc """
  For the system itself, a project and a section, determien whether experiments via
  Upgrade intergration are enabled.
  """
  def experiments_enabled?() do
    case Application.fetch_env!(:oli, :upgrade_experiment_provider)[:user_url] do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  def experiments_enabled?(%Project{has_experiments: true}), do: true
  def experiments_enabled?(%Section{has_experiments: true}), do: true
  def experiments_enabled?(_), do: false

  @doc """
  Serial execution of init, assign and mark. Returns {:ok, condition} for the assigned
  condition code.

  It is important that this integration is based on sending a Torus enrollment_id, rather than a
  user_id, as the Upgrade user identifier.  This allows Upgrade to properly isolate
  a user that might be enrolled in multiple course sections into the specific experiment
  in Upgrade.
  """
  def enroll(enrollment_id, project_slug, decision_point) do
    with {:ok, _} <- init(enrollment_id, project_slug),
         {:ok, assign_results} <- assign(enrollment_id) do
      case assign_results do
        # Upgrade returns an empty array payload in cases when no active
        # experiment applies for this student.
        [] ->
          {:ok, nil}

        results ->
          case mark(enrollment_id, mark_for(results, decision_point)) do
            {:ok, %{"condition" => condition}} ->
              Logger.info("Marked experiment for [#{enrollment_id}] into [#{condition}]")
              {:ok, condition}

            e ->
              Logger.warning("Could not mark experiment #{Kernel.to_string(e)}")
              {:ok, nil}
          end
      end
    else
      {:error, e} ->
        Oli.Utils.Appsignal.capture_error(e)
        Logger.error("Could not enroll into Upgrade #{Kernel.to_string(e)}")
        {:error, e}

      e ->
        Oli.Utils.Appsignal.capture_error(e)
        Logger.error("Could not enroll into Upgrade #{Kernel.to_string(e)}")
        {:error, e}
    end
  end

  @doc """
  Initializes a user and associates them with a group.  Torus paired Upgrade
  experiments will always have an inclusion segment that only allows users
  from a group whose name matches the project slug.
  """
  def init(enrollment_id, project_slug) do
    body = %{
      "id" => Integer.to_string(enrollment_id),
      "group" => %{
        "add-group1" => [project_slug]
      },
      "workingGroup" => %{
        "add-group1" => project_slug
      }
    }

    case http().post(url("/api/init"), encode_body(body), headers()) do
      {:ok, %{status_code: 200, body: result}} ->
        Poison.decode(result)

      e ->
        e
    end
  end

  @doc """
  Requests assignment of a condition code for qualifying experiments.
  """
  def assign(enrollment_id) do
    body =
      encode_body(%{
        "userId" => Integer.to_string(enrollment_id),
        "context" => "add"
      })

    case http().post(url("/api/assign"), body, headers()) do
      {:ok, %{status_code: 200, body: body}} -> Poison.decode(body)
      {:ok, %{status_code: 404}} -> {:error, "Experiment might not be set up correctly."}
      e -> e
    end
  end

  @doc """
  Marks that a user has seen an experiment decision point and condition.
  """
  def mark(enrollment_id, %{decision_point: decision_point, target: target, condition: condition}) do
    body =
      encode_body(%{
        "userId" => Integer.to_string(enrollment_id),
        "site" => decision_point,
        "target" => target,
        "condition" => condition,
        "status" => "condition applied"
      })

    case http().post(url("/api/v1/mark"), body, headers()) do
      {:ok, %{status_code: 200, body: body}} ->
        Poison.decode(body)

      e ->
        e
    end
  end

  @doc """
  Posts a metrics result to Upgrade.
  """
  def log(enrollment_id, correctness, _slug) do
    # format right now DateTime.utc_now() as
    # "2020-03-20 14:00:59"
    now = DateTime.utc_now()
    date = "#{now.year()}-#{now.month()}-#{now.day()}"
    time = "#{now.hour()}:#{now.minute()}:#{now.second()}"
    timestamp = "#{date} #{time}"

    body =
      encode_body(%{
        "userId" => Integer.to_string(enrollment_id),
        "timestamp" => timestamp,
        "value" => [
          %{
            "timestamp" => timestamp,
            "userId" => Integer.to_string(enrollment_id),
            "metrics" => %{
              "groupedMetrics" => [
                %{
                  "groupUniquifier" => timestamp,
                  "groupClass" => "mastery",
                  "groupKey" => "activities",
                  "attributes" => %{
                    "correctness" => correctness
                  }
                }
              ]
            }
          }
        ]
      })

    case http().post(url("/api/log"), body, headers()) do
      {:ok, %{body: body}} ->
        Logger.info("Logged experiment for [#{enrollment_id}]")
        Poison.decode(body)

      {:ok, result} ->
        Kernel.to_string(result)
        |> Oli.Utils.Appsignal.capture_error(result)

        Logger.error("Could not log experiment for [#{enrollment_id}]")
        {:error, result}

      {:error, e} ->
        Oli.Utils.Appsignal.capture_error(e)
        Logger.error("Could not log experiment for [#{enrollment_id}]")
        {:error, e}

      e ->
        Oli.Utils.Appsignal.capture_error(e)
        Logger.error("Could not log experiment for [#{enrollment_id}]")
        e
    end
  end

  defp mark_for(results, decision_point) do
    dp = Enum.find(results, fn d -> d["expPoint"] == decision_point end)

    %{
      decision_point: decision_point,
      target: dp["expId"],
      condition: dp["assignedCondition"]["conditionCode"]
    }
  end

  defp url(suffix) do
    base = Application.fetch_env!(:oli, :upgrade_experiment_provider)[:url]
    "#{base}#{suffix}"
  end

  defp api_token(), do: Application.fetch_env!(:oli, :upgrade_experiment_provider)[:api_token]
  defp encode_body(attrs), do: Poison.encode!(attrs)

  defp headers() do
    case api_token() do
      nil ->
        [
          "Content-Type": "application/json"
        ]

      token ->
        [
          Authorization: "Bearer #{token}",
          "Content-Type": "application/json"
        ]
    end
  end
end
