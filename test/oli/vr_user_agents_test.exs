defmodule Oli.VrUserAgentsTest do
  alias Oli.VrLookupCache
  alias Oli.VrUserAgents
  alias Oli.Accounts.VrUserAgent
  use Oli.DataCase
  import Oli.Factory

  setup do
    user_agent_1 =
      "Mozilla/5.0 (X11; Linux x86_64; Quest 2) AppleWebKit/537.36 (KHTML, like Gecko) OculusBrowser/16.0.0.4.13.298796165 SamsungBrowser/4.0 Chrome/91.0.4472.88 Safari/537.36"

    user_agent_2 =
      "Mozilla/5.0 (Linux; Android 10; Quest 2) AppleWebKit/537.36 (KHTML, like Gecko) OculusBrowser/16.6.0.1.52.314146309 SamsungBrowser/4.0 Chrome/91.0.4472.164 VR Safari/537.36"

    %{user_agent_1: user_agent_1, user_agent_2: user_agent_2}
  end

  describe "count/0" do
    test "returns the number of vr_user_agents", %{
      user_agent_1: user_agent_1,
      user_agent_2: user_agent_2
    } do
      assert VrUserAgents.count() == 0

      for user_agent <- [user_agent_1, user_agent_2] do
        insert(:vr_user_agent, user_agent: user_agent)
      end

      assert VrUserAgents.count() == 2
    end
  end

  describe "get/1" do
    test "returns the vr_user_agent with the given id", %{user_agent_1: user_agent_1} do
      %{id: id} = vr_user_agent = insert(:vr_user_agent, user_agent: user_agent_1)

      assert VrUserAgents.get(id) == vr_user_agent
    end
  end

  describe "insert/1" do
    test "inserts a new vr_user_agent", %{user_agent_1: user_agent_1} do
      params = %{user_agent: user_agent_1}
      {:ok, %{id: id, user_agent: user_agent}} = VrUserAgents.insert(params)

      assert %VrUserAgent{id: ^id, user_agent: ^user_agent} = VrUserAgents.get(id)
    end

    test "returns an error changeset when the user_agent is not unique", %{
      user_agent_1: user_agent_1
    } do
      insert(:vr_user_agent, user_agent: user_agent_1)

      params = %{user_agent: user_agent_1}
      {:error, changeset} = VrUserAgents.insert(params)

      assert changeset.valid? == false
      assert {"has already been taken", _} = changeset.errors[:user_agent]
    end

    test "returns an error changeset when the user_agent is not present", %{} do
      params = %{user_agent: ""}
      {:error, changeset} = VrUserAgents.insert(params)

      assert changeset.valid? == false
      assert {"can't be blank", _} = changeset.errors[:user_agent]
    end
  end

  describe "delete/1" do
    test "deletes the vr_user_agent with the given id", %{user_agent_1: user_agent_1} do
      %{id: id} = _vr_user_agent = insert(:vr_user_agent, user_agent: user_agent_1)

      VrUserAgents.delete(id)

      assert VrUserAgents.get(id) == nil
    end
  end

  # -----------------------
  # Testing cache functions
  # -----------------------

  describe "reload/0" do
    test "reloads the vr_user_agents cache", %{
      user_agent_1: user_agent_1,
      user_agent_2: user_agent_2
    } do
      for user_agent <- [user_agent_1, user_agent_2] do
        insert(:vr_user_agent, user_agent: user_agent)
      end

      VrLookupCache.reload()

      assert VrLookupCache.exists(user_agent_1)
      assert VrLookupCache.exists(user_agent_2)
      refute VrLookupCache.exists("unknown_value")
    end
  end
end
