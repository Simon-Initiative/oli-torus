defmodule Oli.GenAI.HealthProbe do
  @moduledoc "Small real inference probes using Provider credentials and isolated transport capacity."
  alias Oli.GenAI.{PoolManager, Provider}
  alias Oli.GenAI.Completions.{Message, OpenAICompliantProvider}

  @doc "Returns a safe configuration category; deferred adapters never masquerade as healthy."
  def configuration_error(provider, model) do
    cond do
      is_nil(model) ->
        :missing_probe_model

      not is_binary(model.model) or model.model == "" ->
        :invalid_probe_model

      provider.adapter != :open_ai ->
        :unsupported_probe_adapter

      model.provider != :open_ai ->
        :incompatible_probe_model

      not is_binary(provider.api_key) or provider.api_key == "" ->
        :missing_credentials

      match?({:error, _}, Provider.origin(Provider.endpoint(provider, model))) ->
        :invalid_endpoint

      true ->
        nil
    end
  end

  @doc "Executes one bounded non-streaming inference without production routing or fallback."
  def run(provider, model, pool_manager) do
    case configuration_error(provider, model) do
      nil -> infer(provider, model, pool_manager)
      category -> {:configuration_error, category}
    end
  end

  defp infer(provider, model, manager) do
    deadline = Provider.policy(provider).probe_deadline_ms
    url = String.trim_trailing(Provider.endpoint(provider, model), "/") <> "/v1/chat/completions"

    opts = [
      connect_timeout: min(deadline, 8_000),
      checkout_timeout: min(deadline, 1_000),
      recv_timeout: deadline
    ]

    with {:ok, ref} <- PoolManager.connect(manager, {:probe, provider.id}, url, opts) do
      try do
        path = URI.parse(url) |> Map.take([:path, :query])

        target =
          (path.path || "/") <>
            case path.query do
              nil -> ""
              query -> "?" <> query
            end

        headers =
          OpenAICompliantProvider.request_headers(%OpenAI.Config{
            api_key: provider.api_key,
            organization_key: provider.organization_key
          })

        body =
          OpenAICompliantProvider.completion_params(
            model.model,
            [%Message{role: :user, content: "Reply with OK."}],
            [],
            max_tokens: 8
          )
          |> Map.new()
          |> Map.put(:stream, false)
          |> Jason.encode!()

        case :hackney.send_request(ref, {:post, target, headers, body}) do
          {:ok, 200, _, response_ref} -> validate_response(:hackney.body(response_ref, 65_537))
          {:ok, status, _, _} -> {:error, http_category(status)}
          _ -> {:error, :transport_error}
        end
      after
        :hackney.close(ref)
      end
    else
      {:error, :busy} -> {:local_error, :busy}
      {:error, :pool_unavailable} -> {:local_error, :pool_unavailable}
      {:error, :invalid_origin} -> {:configuration_error, :invalid_endpoint}
      _ -> {:error, :transport_error}
    end
  end

  defp validate_response({:ok, body}) when byte_size(body) > 65_536,
    do: {:error, :response_too_large}

  defp validate_response({:ok, body}) do
    case Jason.decode(body) do
      {:ok,
       %{"choices" => [%{"finish_reason" => reason, "message" => %{"content" => content}} | _]}}
      when reason in ["stop", "length"] and is_binary(content) and byte_size(content) > 0 ->
        :ok

      _ ->
        {:error, :invalid_completion}
    end
  end

  defp validate_response(_), do: {:error, :transport_error}
  defp http_category(401), do: :authentication_failed
  defp http_category(403), do: :access_denied
  defp http_category(429), do: :rate_limited
  defp http_category(status) when status >= 500, do: :upstream_unavailable
  defp http_category(_), do: :http_error
end
