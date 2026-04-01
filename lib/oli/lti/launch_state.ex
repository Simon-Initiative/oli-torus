defmodule Oli.Lti.LaunchState do
  @moduledoc """
  Torus-owned signed launch-state envelope for LTI launches.
  """

  @salt "lti_launch_state"
  @scope "lti_launch_state"
  @max_age_seconds 600
  @legacy_flow "legacy_session"
  @storage_flow "client_storage"

  @type classification ::
          :missing_state | :invalid_state | :expired_state | :mismatched_state

  @spec issue(map(), keyword()) :: {:ok, map()}
  def issue(params, opts \\ []) do
    request_id = Keyword.get(opts, :request_id, UUID.uuid4())

    payload = %{
      "scope" => @scope,
      "state_id" => UUID.uuid4(),
      "nonce" => UUID.uuid4(),
      "iss" => params["iss"],
      "client_id" => params["client_id"],
      "target_link_uri" => params["target_link_uri"],
      "flow_mode" => flow_mode(params),
      "storage_supported" => storage_supported?(params),
      "storage_target" => storage_target(params),
      "request_id" => request_id,
      "issued_at" => DateTime.utc_now() |> DateTime.to_unix()
    }

    {:ok, Map.put(payload, "token", sign(payload))}
  end

  @spec resolve(map(), String.t() | nil) :: {:ok, map()} | {:error, classification()}
  def resolve(params, session_state \\ nil) do
    with {:ok, token} <- extract_state(params),
         {:ok, launch_state} <- verify(token),
         :ok <- validate_legacy_session(launch_state, token, session_state) do
      {:ok, launch_state}
    end
  end

  @spec verify(String.t()) :: {:ok, map()} | {:error, classification()}
  def verify(token) when is_binary(token) do
    case Phoenix.Token.verify(OliWeb.Endpoint, @salt, token, max_age: @max_age_seconds) do
      {:ok, %{"scope" => @scope} = payload} ->
        {:ok, Map.put(payload, "token", token)}

      {:ok, _payload} ->
        {:error, :invalid_state}

      {:error, :expired} ->
        {:error, :expired_state}

      {:error, _reason} ->
        {:error, :invalid_state}
    end
  end

  def verify(_token), do: {:error, :invalid_state}

  @spec flow_mode(map()) :: String.t()
  def flow_mode(params) do
    if storage_supported?(params), do: @storage_flow, else: @legacy_flow
  end

  @spec storage_supported?(map()) :: boolean()
  def storage_supported?(params) do
    params
    |> storage_target()
    |> case do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  @spec storage_target(map()) :: String.t() | nil
  def storage_target(params), do: params["lti_storage_target"]

  @spec request_id(Plug.Conn.t()) :: String.t()
  def request_id(conn) do
    conn.assigns[:request_id] ||
      List.first(Plug.Conn.get_req_header(conn, "x-request-id")) ||
      UUID.uuid4()
  end

  @spec state_storage_key(map()) :: String.t()
  def state_storage_key(%{"state_id" => state_id}), do: "torus.lti.launch_state.#{state_id}"

  defp sign(payload), do: Phoenix.Token.sign(OliWeb.Endpoint, @salt, payload)

  defp extract_state(%{"state" => token}) when is_binary(token) and token != "", do: {:ok, token}
  defp extract_state(_params), do: {:error, :missing_state}

  defp validate_legacy_session(%{"flow_mode" => @legacy_flow}, token, session_state)
       when is_binary(session_state) and session_state != token,
       do: {:error, :mismatched_state}

  defp validate_legacy_session(_launch_state, _token, _session_state), do: :ok
end
