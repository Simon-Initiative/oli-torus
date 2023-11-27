defmodule Oli.Notifications.Autoretry do
  use Oban.Worker

  alias HTTPoison, as: H
  alias Oli.Notifications.HttpRetryUtils

  @impl Oban.Worker
  def perform(job) do
    attempt_fn = fn -> H.get(job.args[:url]) end

    opts = %{
      max_attempts: Application.get_env(:my_app, Oli.Repo).max_attempts || 3,
      wait: Application.get_env(:my_app, Oli.Repo).wait || 1000,
      include_404s: Application.get_env(:my_app, Oli.Repo).include_404s || false,
      retry_unknown_errors: Application.get_env(:my_app, Oli.Repo).retry_unknown_errors || false,
      attempt: 1
    }

    case attempt_fn.() do
      {:ok, %H.Response{status_code: 200}} ->
        :ok

      {:ok, %H.Response{status_code: 404}} = response when opts[:include_404s] ->
        Oli.HttpRetryUtils.retry(job, opts)

      {:error, %H.Error{reason: :nxdomain}} ->
        Oli.HttpRetryUtils.retry(job, opts)

      {:error, %H.Error{reason: :timeout}} ->
        Oli.HttpRetryUtils.retry(job, opts)

      {:error, %H.Error{reason: :closed}} ->
        Oli.HttpRetryUtils.retry(job, opts)

      {:error, %H.Error{reason: _}} = response when opts[:retry_unknown_errors] ->
        Oli.HttpRetryUtils.retry(job, opts)

      _ ->
        :ok
    end
  end
end
