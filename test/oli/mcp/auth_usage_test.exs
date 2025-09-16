defmodule Oli.MCP.AuthUsageTest do
  use Oli.DataCase

  alias Oli.MCP.Auth
  alias Oli.MCP.Auth.BearerTokenUsage
  alias Oli.Repo.{Paging, Sorting}

  describe "usage tracking" do
    setup do
      author = author_fixture()
      project_result = project_fixture(author)
      project = project_result.project

      {:ok, {bearer_token, _token_string}} =
        Auth.create_token(author.id, project.id, "test-hint")

      %{
        author: author,
        project: project,
        bearer_token: bearer_token
      }
    end

    test "track_usage/3 creates usage record", %{bearer_token: bearer_token} do
      assert {:ok, usage} =
               Auth.track_usage(bearer_token.id, "init", status: "success")

      assert usage.bearer_token_id == bearer_token.id
      assert usage.event_type == "init"
      assert usage.status == "success"
      assert usage.occurred_at
    end

    test "track_usage/3 with tool name", %{bearer_token: bearer_token} do
      assert {:ok, usage} =
               Auth.track_usage(bearer_token.id, "tool",
                 tool_name: "create_activity",
                 status: "success"
               )

      assert usage.tool_name == "create_activity"
      assert usage.event_type == "tool"
    end

    test "track_usage/3 with resource URI", %{bearer_token: bearer_token} do
      assert {:ok, usage} =
               Auth.track_usage(bearer_token.id, "resource",
                 resource_uri: "torus://schemas/common/content",
                 status: "success"
               )

      assert usage.resource_uri == "torus://schemas/common/content"
      assert usage.event_type == "resource"
    end

    test "track_usage_by_token/3 works with token string", %{bearer_token: bearer_token} do
      # Need to generate a token string for this test
      {:ok, {_bearer_token, token_string}} =
        Auth.regenerate_token(bearer_token.author_id, bearer_token.project_id)

      assert {:ok, usage} =
               Auth.track_usage_by_token(token_string, "init", status: "success")

      assert usage.event_type == "init"
      assert usage.status == "success"
    end

    test "browse_tokens_with_usage/3 returns tokens with usage stats", %{
      author: author,
      project: project,
      bearer_token: bearer_token
    } do
      # Create some usage records
      Auth.track_usage(bearer_token.id, "init")
      Auth.track_usage(bearer_token.id, "tool", tool_name: "create_activity")
      Auth.track_usage(bearer_token.id, "resource", resource_uri: "torus://schemas")

      results =
        Auth.browse_tokens_with_usage(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :inserted_at, direction: :desc},
          %Auth.BrowseOptions{text_search: ""}
        )

      assert length(results) == 1
      result = List.first(results)

      assert result.bearer_token.id == bearer_token.id
      assert result.author.id == author.id
      assert result.project.id == project.id
      assert result.total_usage == 3
      assert result.total_count == 1
    end
  end

  describe "usage validation" do
    test "requires valid event type" do
      changeset =
        %BearerTokenUsage{}
        |> BearerTokenUsage.changeset(%{
          bearer_token_id: 1,
          event_type: "invalid",
          occurred_at: DateTime.utc_now()
        })

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).event_type
    end

    test "tool event requires tool_name" do
      changeset =
        %BearerTokenUsage{}
        |> BearerTokenUsage.changeset(%{
          bearer_token_id: 1,
          event_type: "tool",
          occurred_at: DateTime.utc_now()
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).tool_name
    end

    test "resource event requires resource_uri" do
      changeset =
        %BearerTokenUsage{}
        |> BearerTokenUsage.changeset(%{
          bearer_token_id: 1,
          event_type: "resource",
          occurred_at: DateTime.utc_now()
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).resource_uri
    end
  end
end
