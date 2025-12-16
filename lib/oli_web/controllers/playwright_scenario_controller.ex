defmodule OliWeb.PlaywrightScenarioController do
  use OliWeb, :controller

  require Logger

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @max_yaml_bytes 100_000

  def run(conn, _params) do
    with :ok <- authorize(conn),
         {:ok, yaml, params} <- extract_payload(conn),
         {:ok, result} <- execute_yaml(yaml, params) do
      json(conn, %{
        ok: true,
        outputs: build_outputs(result, params),
        summary: Scenarios.summarize(result)
      })
    else
      {:error, :unauthorized} ->
        send_resp(conn, :unauthorized, "unauthorized")

      {:error, :bad_request} ->
        send_resp(conn, :bad_request, "bad_request")

      {:error, {:scenario_failed, result}} ->
        Logger.error("Playwright scenario failed: #{inspect(result.errors)}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          ok: false,
          errors:
            Enum.map(result.errors, fn {directive, reason} ->
              %{directive: inspect(directive), reason: reason}
            end),
          summary: Scenarios.summarize(result)
        })

      {:error, reason} ->
        Logger.error("Playwright scenario execution failed: #{inspect(reason)}")
        send_resp(conn, :internal_server_error, "scenario_failed")
    end
  end

  defp authorize(conn) do
    token = scenario_token()

    with [provided] <- get_req_header(conn, "x-playwright-scenario-token"),
         false <- is_nil(token),
         true <- provided == token do
      :ok
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp extract_payload(%Plug.Conn{body_params: %Plug.Conn.Unfetched{}} = conn) do
    case Plug.Conn.read_body(conn, length: @max_yaml_bytes) do
      {:ok, body, _conn} ->
        with {:ok, decoded} <- Jason.decode(body) do
          extract_from_map(decoded)
        else
          _ -> {:error, :bad_request}
        end

      {:more, _, _} ->
        {:error, :bad_request}
    end
  end

  defp extract_payload(%Plug.Conn{body_params: params}) do
    extract_from_map(params)
  end

  defp extract_from_map(%{"yaml" => yaml} = payload) when is_binary(yaml) do
    params = Map.get(payload, "params", %{})

    if is_map(params) do
      {:ok, yaml, params}
    else
      {:error, :bad_request}
    end
  end

  defp extract_from_map(_), do: {:error, :bad_request}

  defp execute_yaml(yaml, params) do
    interpolated = interpolate(yaml, params)

    result =
      interpolated
      |> Scenarios.execute_yaml(RuntimeOpts.build())

    if Scenarios.has_errors?(result) do
      {:error, {:scenario_failed, result}}
    else
      {:ok, result}
    end
  rescue
    e ->
      Logger.error("Scenario YAML execution error: #{Exception.message(e)}")
      {:error, e}
  end

  defp interpolate(yaml, params) do
    Enum.reduce(params, yaml, fn {key, value}, acc ->
      placeholder = "${#{key}}"
      String.replace(acc, placeholder, to_string(value || ""))
    end)
  end

  defp build_outputs(result, params) do
    state = result.state

    %{
      params: params,
      projects: map_entities(state.projects, fn built -> built.project.slug end),
      sections: map_entities(state.sections, fn section -> section.slug end),
      products: map_entities(state.products, fn product -> product.slug end),
      users: map_entities(state.users, fn user -> Map.get(user, :email) end)
    }
  end

  defp map_entities(nil, _fun), do: %{}

  defp map_entities(map, fun) do
    Enum.reduce(map, %{}, fn {name, entity}, acc ->
      Map.put(acc, name, safe_apply(fun, entity))
    end)
  end

  defp safe_apply(fun, entity) do
    fun.(entity)
  rescue
    _ -> nil
  end

  defp scenario_token do
    Application.get_env(:oli, :playwright_scenario_token)
  end
end
