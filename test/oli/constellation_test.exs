defmodule Oli.ConstellationTest do
  require ECL.Constellation
  alias ECL.Constellation, as: Constellation

  use ExUnit.Case, async: true

  describe "ECL connection" do
    test "it connects" do

      user_name = System.get_env("ECL_USERNAME", "")
      password = System.get_env("ECL_PASSWORD", "")

      auth_token = Constellation.login(user_name, password)
      me = Constellation.me(auth_token)

      Constellation.download(auth_token, Map.get(me, "Id"), ["Name", "Email", "CakePreference"])
      |> IO.inspect()

      result = Constellation.execute_sll_expression(auth_token, "1 + 1")
      IO.inspect(result)
    end
  end
end
