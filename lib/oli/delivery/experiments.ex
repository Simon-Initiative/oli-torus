defmodule Oli.Delivery.Experiments do

  import Oli.HTTP
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section


  @doc """
  For the system itself, a project and a section, determien whether experiments via
  Upgrade intergration are enabled.
  """
  def experiments_enabled?() do
    case Application.fetch_env(:oli, :upgrade_experiment_provider) do
      :error -> false
      _ -> true
    end
  end

  def experiments_enabled?(%Project{has_experiments: true}), do: true
  def experiments_enabled?(%Section{has_experiments: true}), do: true
  def experiments_enabled?(_), do: false

  @doc """
  Serial execution of init, assign and mark. Returns {:ok, condition} for the assigned
  condition code.
  """
  def enroll(enrollment_id, project_slug, decision_point) do
    with {:ok, _} <- init(enrollment_id, project_slug),
      {:ok, assign_results} <- assign(enrollment_id)
    do
      case assign_results do
        [] ->
          {:ok, nil}
        results ->
          case mark(enrollment_id, mark_for(results, decision_point)) do
            {:ok, %{"condition" => condition}} ->
              {:ok, condition}
            _ ->
              {:ok, nil}
          end
      end

    else
      e -> e
    end
  end

  def init(enrollment_id, project_slug) do

    body = %{
      "id" => enrollment_id,
      "group" => %{
        "add-group1" => [project_slug]
      },
      "workingGroup" => %{
        "add-group1" => project_slug
      }
    }

    case http().post(url("/api/init"), encode_body(body), headers()) do
      {:ok, %{status_code: 200, body: result}} -> Poison.decode(result)
      e -> e
    end
  end

  def assign(enrollment_id) do
    body = encode_body(%{
      "userId" => enrollment_id,
      "context" => "add"
    })

    case http().post(url("/api/assign"), body, headers()) do
      {:ok, %{status_code: 200, body: body}} ->  Poison.decode(body)
      e -> e
    end
  end

  def mark(enrollment_id, %{decision_point: decision_point, target: target, condition: condition}) do

    body = encode_body(%{
      "userId" => enrollment_id,
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

  def log(enrollment_id, correctness) do
    body = encode_body(%{
      "userId" => enrollment_id,
      "value" => [
        %{
          "userId" => enrollment_id,
          "metrics" => %{
            "groupedMetrics" => [
              %{
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

    case http().post(url("/api/v1/log"), body, headers()) do
      {:ok, %{status_code: 200, body: body}} -> Poison.decode(body)
      e -> e |> IO.inspect
    end
  end

  def mark_for(results, decision_point) do
    dp = Enum.find(results, fn d -> d["expPoint"] == decision_point end)

    %{decision_point: decision_point, target: dp["expId"], condition: dp["assignedCondition"]["conditionCode"]}
  end

  defp url(suffix) do
    base = Application.fetch_env!(:oli, :upgrade_experiment_provider)[:url]
    "#{base}#{suffix}"
  end

  defp api_token(), do: Application.fetch_env!(:oli, :upgrade_experiment_provider)[:api_token]
  defp encode_body(attrs), do: Poison.encode!(attrs)

  defp headers() do
    case api_token() do
      nil -> [
        "Content-Type": "application/json"
      ]
      token -> [
        Authorization: "Bearer #{token}",
        "Content-Type": "application/json"
      ]
    end
  end


end
