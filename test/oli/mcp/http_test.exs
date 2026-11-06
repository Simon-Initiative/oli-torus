defmodule Oli.MCP.HTTPTest do
  use OliWeb.ConnCase, async: false

  import Oli.Factory

  alias Oli.MCP.Auth
  alias Oli.MCP.Server

  setup do
    start_supervised!({Server, transport: {:streamable_http, start: true}})
    :ok
  end

  test "reads project content through the HTTP initialization and request flow" do
    author = insert(:author)
    project = insert(:project, authors: [author])
    {:ok, {_, token}} = Auth.create_token(author.id, project.id)
    session = initialize(token)
    uri = "torus://p/#{project.slug}"

    conn = rpc(token, session, "resources/read", %{"uri" => uri})
    assert %{"result" => %{"contents" => [content]}} = json_response(conn, 200)
    assert content["uri"] == uri
    assert content["mimeType"] == "application/vnd.torus.project+json"
    assert Jason.decode!(content["text"])["slug"] == project.slug
  end

  test "discovers all project templates over HTTP" do
    author = insert(:author)
    project = insert(:project, authors: [author])
    {:ok, {_, token}} = Auth.create_token(author.id, project.id)
    session = initialize(token)

    conn = rpc(token, session, "resources/templates/list", %{})
    assert %{"result" => %{"resourceTemplates" => templates}} = json_response(conn, 200)
    assert length(templates) == 7
    assert Enum.any?(templates, &(&1["uriTemplate"] == "torus://p/{project}/hierarchy"))
  end

  test "uses each request's token when sessions alternate, and rejects cross-project reads" do
    author = insert(:author)
    first = insert(:project, authors: [author])
    second = insert(:project, authors: [author])
    {:ok, {_, first_token}} = Auth.create_token(author.id, first.id)
    {:ok, {_, second_token}} = Auth.create_token(author.id, second.id)
    first_session = initialize(first_token)
    second_session = initialize(second_token)

    for {token, session, project} <- [
          {first_token, first_session, first},
          {second_token, second_session, second},
          {first_token, first_session, first}
        ] do
      conn = rpc(token, session, "resources/read", %{"uri" => "torus://p/#{project.slug}"})
      assert %{"result" => %{"contents" => [content]}} = json_response(conn, 200)
      assert Jason.decode!(content["text"])["slug"] == project.slug
    end

    conn =
      rpc(first_token, first_session, "resources/read", %{"uri" => "torus://p/#{second.slug}"})

    assert %{"error" => %{"code" => -32002}} = json_response(conn, 200)
  end

  test "rejects missing, invalid, and revoked tokens on an initialized session" do
    author = insert(:author)
    project = insert(:project, authors: [author])
    {:ok, {record, token}} = Auth.create_token(author.id, project.id)
    session = initialize(token)
    params = %{"uri" => "torus://p/#{project.slug}"}

    for invalid <- [nil, "invalid"] do
      assert %{"error" => %{"code" => -32002}} =
               invalid |> rpc(session, "resources/read", params) |> json_response(200)
    end

    {:ok, _} = Auth.update_token_status(record.id, :disabled)

    assert %{"error" => %{"code" => -32002}} =
             token |> rpc(session, "resources/read", params) |> json_response(200)
  end

  test "authorizes activity creation with each request's token when sessions alternate" do
    author = insert(:author)
    first = insert(:project, authors: [author])
    second = insert(:project, authors: [author])

    for project <- [first, second] do
      insert(:publication, project: project, root_resource_id: nil, published: nil)
    end

    {:ok, {_, first_token}} = Auth.create_token(author.id, first.id)
    {:ok, {_, second_token}} = Auth.create_token(author.id, second.id)
    first_session = initialize(first_token)
    second_session = initialize(second_token)
    revision_count = Oli.Repo.aggregate(Oli.Resources.Revision, :count)

    conn = rpc(first_token, first_session, "tools/call", create_activity_params(second))

    assert %{"result" => %{"isError" => true, "content" => [%{"text" => text}]}} =
             json_response(conn, 200)

    assert text =~ "Authorization failed"
    assert Oli.Repo.aggregate(Oli.Resources.Revision, :count) == revision_count

    for {token, session, project} <- [
          {first_token, first_session, first},
          {second_token, second_session, second},
          {first_token, first_session, first}
        ] do
      conn = rpc(token, session, "tools/call", create_activity_params(project))

      assert %{"result" => %{"isError" => false, "content" => [%{"text" => text}]}} =
               json_response(conn, 200)

      assert %{"success" => true, "activity" => %{"revision_id" => revision_id}} =
               Jason.decode!(text)

      revision = Oli.Resources.get_revision!(revision_id)

      assert Oli.Repo.get_by(Oli.Authoring.Course.ProjectResource,
               project_id: project.id,
               resource_id: revision.resource_id
             )
    end

    assert Oli.Repo.aggregate(Oli.Resources.Revision, :count) == revision_count + 3
  end

  test "rejects activity creation with missing, invalid, and revoked request tokens" do
    author = insert(:author)
    project = insert(:project, authors: [author])
    insert(:publication, project: project, root_resource_id: nil, published: nil)
    {:ok, {record, token}} = Auth.create_token(author.id, project.id)
    session = initialize(token)
    params = create_activity_params(project)
    revision_count = Oli.Repo.aggregate(Oli.Resources.Revision, :count)

    for invalid <- [nil, "invalid"] do
      assert %{"error" => %{"code" => -32000}} =
               invalid |> rpc(session, "tools/call", params) |> json_response(200)
    end

    {:ok, _} = Auth.update_token_status(record.id, :disabled)

    assert %{"error" => %{"code" => -32000}} =
             token |> rpc(session, "tools/call", params) |> json_response(200)

    assert Oli.Repo.aggregate(Oli.Resources.Revision, :count) == revision_count
  end

  test "unauthenticated initialization preserves the server and existing sessions" do
    author = insert(:author)
    project = insert(:project, authors: [author])
    {:ok, {_, token}} = Auth.create_token(author.id, project.id)
    session = initialize(token)
    server = Anubis.Server.Registry.server(Server)
    params = %{"uri" => "torus://p/#{project.slug}"}

    for invalid <- [nil, "invalid"] do
      invalid_session = initialize(invalid)
      assert Anubis.Server.Registry.server(Server) == server
      assert :sys.get_state(server).frame.assigns == %{}

      assert %{"error" => %{"code" => -32002}} =
               invalid |> rpc(invalid_session, "resources/read", params) |> json_response(200)

      assert %{"error" => %{"code" => -32000}} =
               invalid
               |> rpc(invalid_session, "tools/call", create_activity_params(project))
               |> json_response(200)

      assert %{"result" => %{"contents" => [_]}} =
               token |> rpc(session, "resources/read", params) |> json_response(200)
    end
  end

  test "preserves static resources and tool dispatch" do
    author = insert(:author)
    project = insert(:project, authors: [author])
    {:ok, {_, token}} = Auth.create_token(author.id, project.id)
    session = initialize(token)

    for uri <- ["torus://schemas", "torus://examples"] do
      conn = rpc(token, session, "resources/read", %{"uri" => uri})
      assert %{"result" => %{"contents" => [%{"uri" => ^uri}]}} = json_response(conn, 200)
    end

    conn = rpc(token, session, "tools/list", %{})
    assert %{"result" => %{"tools" => tools}} = json_response(conn, 200)

    assert Enum.sort(Enum.map(tools, & &1["name"])) ==
             ["activity_test_eval_tool", "activity_validation_tool", "create_activity_tool"]

    conn =
      rpc(token, session, "tools/call", %{
        "name" => "activity_validation_tool",
        "arguments" => %{"activity_json" => "invalid JSON"}
      })

    assert %{"result" => %{"isError" => true, "content" => [%{"text" => text}]}} =
             json_response(conn, 200)

    assert text =~ "Validation failed"
  end

  defp create_activity_params(project) do
    %{
      "name" => "create_activity_tool",
      "arguments" => %{
        "project_slug" => project.slug,
        "activity_type_slug" => "oli_multiple_choice",
        "activity_json" =>
          Jason.encode!(%{
            "stem" => %{
              "id" => "stem_1",
              "content" => [%{"type" => "p", "children" => [%{"text" => "Test question"}]}],
              "editor" => "slate",
              "textDirection" => "ltr"
            },
            "authoring" => %{
              "version" => 2,
              "parts" => [],
              "transformations" => [],
              "previewText" => "Test question"
            }
          })
      }
    }
  end

  defp initialize(token) do
    conn =
      rpc(token, nil, "initialize", %{
        "protocolVersion" => "2025-03-26",
        "capabilities" => %{},
        "clientInfo" => %{"name" => "torus-regression-test", "version" => "1.0"}
      })

    assert %{"result" => %{"serverInfo" => _}} = json_response(conn, 200)
    [session] = get_resp_header(conn, "mcp-session-id")

    conn = request(token, session, %{"jsonrpc" => "2.0", "method" => "notifications/initialized"})
    assert conn.status == 202
    # Notifications are asynchronous; this call also waits for initialization to finish.
    :sys.get_state(Anubis.Server.Registry.server(Server))
    session
  end

  defp rpc(token, session, method, params) do
    request(token, session, %{
      "jsonrpc" => "2.0",
      "id" => System.unique_integer([:positive]),
      "method" => method,
      "params" => params
    })
  end

  defp request(token, session, message) do
    conn =
      build_conn()
      |> put_req_header("accept", "application/json, text/event-stream")
      |> put_req_header("content-type", "application/json")

    conn =
      case token do
        nil -> conn
        token -> put_req_header(conn, "authorization", "Bearer #{token}")
      end

    conn =
      case session do
        nil -> conn
        session -> put_req_header(conn, "mcp-session-id", session)
      end

    post(conn, "/mcp", Jason.encode!(message))
  end
end
