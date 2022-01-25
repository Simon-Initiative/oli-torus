defmodule Oli.Utils.DatabaseTest do
  use ExUnit.Case, async: true

  alias Oli.Utils.Database

  describe "can parse the database user from the url" do
    test "it parses correctly" do
      assert "user" ==
               Database.parse_user_from_db_url("ecto://user:password@example.com", "default")

      assert "default" ==
               Database.parse_user_from_db_url("invalid", "default")
    end
  end
end
