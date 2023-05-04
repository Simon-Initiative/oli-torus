defmodule OliWeb.Api.ECLController do
  use OliWeb, :controller

  require ECL.Constellation
  alias ECL.Constellation, as: Constellation

  def eval(conn, %{"code" => code}) do
    user_name = System.get_env("ECL_USERNAME", "")
    password = System.get_env("ECL_PASSWORD", "")

    # Login
    auth_token = Constellation.login(user_name, password)

    # Execute
    result = Constellation.execute_sll_expression(auth_token, code)

    json(conn, %{"result" => result})
  end

end
