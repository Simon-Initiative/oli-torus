defmodule Oli.VrUserAgentsTest do
  use Oli.DataCase
  import Oli.Factory
  alias Oli.Accounts.Schemas.VrUserAgent
  alias Oli.VrUserAgents

  describe "count/0" do
    test "returns the number of vr_user_agents" do
      assert VrUserAgents.count() == 0

      for _ <- 1..3 do
        insert(:vr_user_agent, user_id: insert(:user).id)
      end

      assert VrUserAgents.count() == 3
    end
  end

  describe "get/1" do
    test "returns the vr_user_agent with the given user_id" do
      user = insert(:user)
      vr_user_agent = insert(:vr_user_agent, user_id: user.id)

      assert VrUserAgents.get(user.id) == vr_user_agent
    end
  end

  describe "insert/1" do
    test "inserts a new vr_user_agent" do
      %{id: user_id} = _user = insert(:user)
      VrUserAgents.insert(%{user_id: user_id, value: true})

      assert %VrUserAgent{user_id: ^user_id, value: true} = VrUserAgents.get(user_id)
    end
  end

  describe "update/2" do
    test "updates the vr_user_agent with the given user_id" do
      %{id: user_id} = _user = insert(:user)
      vr_user_agent = insert(:vr_user_agent, user_id: user_id)

      assert vr_user_agent.value == false

      VrUserAgents.update(vr_user_agent, %{value: true})

      assert %VrUserAgent{user_id: ^user_id, value: true} = VrUserAgents.get(user_id)
    end
  end

  describe "delete/1" do
    test "deletes the vr_user_agent with the given user_id" do
      user = insert(:user)
      vr_user_agent = insert(:vr_user_agent, user_id: user.id)

      assert VrUserAgents.get(user.id) == vr_user_agent

      VrUserAgents.delete(user.id)

      assert VrUserAgents.get(user.id) == nil
    end
  end

  describe "search_user_for_vr/2" do
    test "searches user for vr_user_agent by id" do
      %{id: id, name: name, email: email} = _user = insert(:user)

      assert [
               %{value: false, user_name: ^name, user_id: ^id, user_email: ^email}
             ] = VrUserAgents.search_user_for_vr("#{id}", "id")
    end

    test "searches user for vr_user_agent by name" do
      %{id: id, name: name, email: email} = _user = insert(:user)

      assert [
               %{value: false, user_name: ^name, user_id: ^id, user_email: ^email}
             ] = VrUserAgents.search_user_for_vr("#{name}", "name")
    end

    test "searches user for vr_user_agent by email" do
      %{id: id, name: name, email: email} = _user = insert(:user)

      assert [
               %{value: false, user_name: ^name, user_id: ^id, user_email: ^email}
             ] = VrUserAgents.search_user_for_vr("#{email}", "email")
    end

    test "searches user for vr_user_agent excludes already registered" do
      %{id: id, name: _name, email: email} = _user = insert(:user)
      insert(:vr_user_agent, user_id: id)

      assert [] = VrUserAgents.search_user_for_vr("#{email}", "email")
    end
  end

  describe "vr_user_agents" do
    test "lists all vr_user_agents" do
      %{id: user_id, name: user_name} = _user = insert(:user)
      _vr_user_agent = insert(:vr_user_agent, user_id: user_id)

      assert [%{user_id: ^user_id, value: false, name: ^user_name}] =
               VrUserAgents.vr_user_agents()
    end
  end
end
