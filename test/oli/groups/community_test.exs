defmodule Oli.Groups.CommunityTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Groups.Community

  describe "changeset/2" do
    test "changeset should be invalid if name is empty" do
      changeset =
        build(:community, %{name: ""})
        |> Community.changeset()

      refute changeset.valid?
    end
  end
end
