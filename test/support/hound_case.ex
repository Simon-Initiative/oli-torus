defmodule Oli.HoundCase do
  use ExUnit.CaseTemplate
  use Hound.Helpers

  # Use hound_test instead of test for integration tests, this will get you a screenshot on failure
  defmacro hound_test(
             message,
             var \\ quote do
               _
             end,
             contents
           ) do
    prefix = String.replace(message, ~r/\W+/, "-")
    filename = "test-results/screenshots/#{prefix}.png"

    quote do
      test unquote(message), unquote(var) do
        try do
          unquote(contents)
        rescue
          error ->
            take_screenshot(unquote(filename))
            Logger.warn("Test failed, screenshot saved to #{unquote(filename)}")
            Kernel.reraise(error, __STACKTRACE__)
        end
      end
    end
  end

  using do
    quote do
      alias Oli.Repo
      alias Oli.Seeder
      use Hound.Helpers
      require Logger

      @tag timeout: 180_000
      @tag :hound

      hound_session(
        driver: %{chromeOptions: %{"args" => Application.get_env(:hound, :chrome_args)}}
      )

      import Oli.HoundCase, only: [hound_test: 2, hound_test: 3]
    end
  end
end
