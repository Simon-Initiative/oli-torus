defmodule Oli.ConstellationTest do
  require ECL.Constellation
  alias ECL.Constellation, as: Constellation

  use ExUnit.Case, async: true

  describe "ECL connection" do
    test "it connects" do
      auth_token = Constellation.login("darrensiegel+torus@cmu.edu", "pvfr4BGT%")
      me = Constellation.me(auth_token)

      Constellation.download(auth_token, Map.get(me, "Id"), ["Name", "Email", "CakePreference"])
      |> IO.inspect()

      result = Constellation.execute_sll_expression(auth_token, "Inspect[Object[Resource]]")
      IO.inspect(result)
    end
  end
end
