defmodule Oli.Plugs.LoadTestingCSRFBypass do

  def init(opts), do: opts

  def call(conn, _opts) do

    # During load testing, we allow CSRF checks to be bypassed to simplify
    # load testing scenario implementation
    if Oli.Utils.LoadTesting.enabled?() do
      private = Map.put(conn.private, :plug_skip_csrf_protection, true)
      Map.put(conn, :private, private)
    else
      conn
    end

  end

end
