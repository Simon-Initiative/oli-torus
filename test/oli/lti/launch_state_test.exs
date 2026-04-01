defmodule Oli.Lti.LaunchStateTest do
  use ExUnit.Case, async: true

  alias Oli.Lti.LaunchState

  test "issues and verifies a signed launch state" do
    {:ok, launch_state} =
      LaunchState.issue(%{
        "iss" => "https://example.edu",
        "client_id" => "client-1",
        "target_link_uri" => "https://tool.example.edu/lti/launch"
      })

    assert {:ok, verified} = LaunchState.verify(launch_state["token"])
    assert verified["iss"] == "https://example.edu"
    assert verified["client_id"] == "client-1"
    assert verified["flow_mode"] == "legacy_session"
  end

  test "detects missing state" do
    assert {:error, :missing_state} = LaunchState.resolve(%{}, nil)
  end

  test "detects mismatched legacy session state" do
    {:ok, launch_state} =
      LaunchState.issue(%{
        "iss" => "https://example.edu",
        "client_id" => "client-1",
        "target_link_uri" => "https://tool.example.edu/lti/launch"
      })

    assert {:error, :mismatched_state} =
             LaunchState.resolve(%{"state" => launch_state["token"]}, "other-state")
  end

  test "classifies storage-capable launches from lti_storage_target" do
    assert LaunchState.flow_mode(%{"lti_storage_target" => "post_message_forwarding"}) ==
             "client_storage"
  end
end
