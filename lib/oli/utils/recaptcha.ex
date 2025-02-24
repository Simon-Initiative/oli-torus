defmodule Oli.Utils.Recaptcha do
  @moduledoc """
    A module for verifying reCAPTCHA version 2.0 response strings.
    See the [documentation](https://developers.google.com/recaptcha/docs/verify)
    for more details.
  """
  import Oli.HTTP

  @headers [
    {"Content-type", "application/x-www-form-urlencoded"},
    {"Accept", "application/json"}
  ]

  @spec verify(String.t()) :: {:success, boolean()}

  def verify(""), do: {:success, false}
  def verify(nil), do: {:success, false}

  def verify(response_string) do
    timeout = Application.fetch_env!(:oli, :recaptcha)[:timeout]
    url = Application.fetch_env!(:oli, :recaptcha)[:verify_url]

    body =
      [secret: Application.fetch_env!(:oli, :recaptcha)[:secret]]
      |> Keyword.put(:response, response_string)
      |> URI.encode_query()

    result =
      with {:ok, response} <- http().post(url, body, @headers, timeout: timeout),
           {:ok, data} <- Jason.decode(response.body) do
        {:ok, data}
      end

    case result do
      {:ok, %{"success" => true}} -> {:success, true}
      {:ok, %{"success" => false}} -> {:success, false}
      {:error, _errors} -> {:success, false}
    end
  end
end
