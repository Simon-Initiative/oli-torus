# A helper task that runs `mix test` in the :hound environment
# To use it, start up an instance of chromedriver, and then run `mix test.hound`
# This will exclude all tests except those tagged as "hound"
# The :hound environment will cause the application to start and listen on port 9443 by default and
# interacts with the same database as the :test environment. It will use the SSL keys found
# in "priv/ssl" so your tests should use the "--allow-insecure-localhost" option
defmodule Mix.Tasks.Test.Hound do
  use Mix.Task

  def run(args) do
    # The test task has an explicit check and will refuse to run in other environments unless
    # MIX_ENV is actually set, just having a preferred_cli_env in mix.exs was not enough.
    System.put_env("MIX_ENV", "hound")
    Mix.Task.run("test", args)
  end
end
