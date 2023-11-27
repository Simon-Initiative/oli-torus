defmodule Oli.Notifications.Autoretry do
  import Elixir.HTTPoison
  @max_attempts 5
  @reattempt_wait 15_000
  defmacro autoretry(attempt, opts \\ []) do
    quote location: :keep, generated: true do
      attempt_fn = fn -> unquote(attempt) end

      opts =
        Keyword.merge(
          [
            max_attempts: unquote(@max_attempts),
            wait: unquote(@reattempt_wait),
            include_404s: false,
            retry_unknown_errors: false,
            attempt: 1
          ],
          unquote(opts)
        )

      case attempt_fn.() do
        # Error conditions
        {:error, %HTTPoison.Error{id: nil, reason: :nxdomain}} ->
          next_attempt(attempt_fn, opts)

        {:error, %HTTPoison.Error{id: nil, reason: :timeout}} ->
          next_attempt(attempt_fn, opts)

        {:error, %HTTPoison.Error{id: nil, reason: :closed}} ->
          next_attempt(attempt_fn, opts)

        {:error, %HTTPoison.Error{id: nil, reason: _}} = response ->
          if Keyword.get(opts, :retry_unknown_errors) do
            next_attempt(attempt_fn, opts)
          else
            response
          end

        # OK conditions
        {:ok, %HTTPoison.Response{status_code: 500}} ->
          next_attempt(attempt_fn, opts)

        {:ok, %HTTPoison.Response{status_code: 404}} = response ->
          if Keyword.get(opts, :include_404s) do
            next_attempt(attempt_fn, opts)
          else
            response
          end

        response ->
          response
      end
    end
  end

  def next_attempt(attempt, opts) do
    Process.sleep(opts[:wait])

    if opts[:max_attempts] == :infinity || opts[:attempt] < opts[:max_attempts] - 1 do
      opts = Keyword.put(opts, :attempt, opts[:attempt] + 1)
      autoretry(attempt.(), opts)
    else
      attempt.()
    end
  end
end
