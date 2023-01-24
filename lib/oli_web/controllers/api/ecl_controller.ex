defmodule OliWeb.Api.ECLController do
  use OliWeb, :controller

  require ECL.Constellation
  alias ECL.Constellation, as: Constellation

  def eval(conn, %{"code" => code}) do
    user_name = System.get_env("ECL_USERNAME", "")
    password = System.get_env("ECL_PASSWORD", "")

    # Login
    mark = :os.system_time(:millisecond)
    auth_token = Constellation.login(user_name, password)
    time = :os.system_time(:millisecond) - mark
    IO.inspect("Constellation.login: #{time}ms")

    # Execute
    mark = :os.system_time(:millisecond)
    result = Constellation.execute_sll_expression(auth_token, code)
    time = :os.system_time(:millisecond) - mark
    IO.inspect("Constellation.execute_sll_expression: #{time}ms")

    json(conn, %{"result" => result})
  end

end
