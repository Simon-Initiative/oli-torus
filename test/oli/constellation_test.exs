defmodule Oli.ConstellationTest do
  require ECL.Constellation
  alias ECL.Constellation, as: Constellation

  use ExUnit.Case, async: true

  describe "ECL connection" do
    test "it connects" do

      user_name = Application.get_env(:ecl, :username)
      password = Application.get_env(:ecl, :password)

      auth_token = Constellation.login(user_name, password)
      me = Constellation.me(auth_token)

      Constellation.download(auth_token, Map.get(me, "Id"), ["Name", "Email", "CakePreference"])
      |> IO.inspect()

      result = Constellation.execute_sll_expression(auth_token, "Inspect[Object[Resource]]")
      IO.inspect(result)
    end
  end
end
