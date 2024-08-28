defmodule Oli.Activities.Transformers.VariableSubstitution.RestImpl do
  alias Oli.Activities.Transformers.VariableSubstitution.Strategy
  alias Oli.Activities.Transformers.VariableSubstitution.Common

  import Oli.HTTP

  require Logger

  @behaviour Strategy

  @impl Strategy
  def substitute(model, evaluation_digest) do
    Common.replace_variables(model, evaluation_digest)
  end

  @impl Strategy
  def provide_batch_context(transformers) do
    url = Application.fetch_env!(:oli, :variable_substitution)[:rest_endpoint_url]

    body =
      %{
        vars: Enum.map(transformers, fn t -> Enum.map(t.data, fn d -> d end) end),
        count: 1
      }
      |> Poison.encode!()

    headers = [
      "Content-Type": "application/json"
    ]

    case http().post(url, body, headers, []) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Poison.decode(body)

      {:ok, %HTTPoison.Response{}} ->
        {:error, "Error retrieving the payload"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
