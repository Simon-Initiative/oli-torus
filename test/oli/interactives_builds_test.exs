defmodule Oli.Interactives.BuildsTest do
  use Oli.DataCase
  import Mox
  import Phoenix.ConnTest

  alias HTTPoison.Response
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Interactives.{Build, Builds, Bundle}
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Test.{MockHTTP, MockAws}

  @endpoint OliWeb.Endpoint
  setup :verify_on_exit!

  setup do
    seed =
      Seeder.base_project_with_resource2()
      |> Seeder.add_objective("Measure concentration", :skill)
      |> Seeder.add_objective_with_children("Chemistry", [:skill], :objective)

    model = %{
      "stem" => %{"id" => "stem", "content" => []},
      "authoring" => %{
        "prompt" => "",
        "selectedSkillIds" => [],
        "previewText" => "",
        "parts" => [
          %{
            "id" => "placeholder",
            "responses" => [],
            "hints" => [],
            "scoringStrategy" => "average"
          }
        ]
      }
    }

    {:ok, {activity, _}} =
      ActivityEditor.create(seed.project.slug, "oli_interactive", seed.author, model, [])

    assert {:acquired} =
             Oli.Authoring.Locks.acquire(
               seed.project.slug,
               seed.publication.id,
               activity.resource_id,
               seed.author.id
             )

    params = %{
      "prompt" => "Build a concentration lab",
      "selectedSkillIds" => [seed.skill.resource.id],
      "model" => "gpt-6-sol",
      "reasoning" => "low",
      "lockId" => activity.resource_id
    }

    Map.merge(seed, %{activity: activity, params: params})
  end

  test "author API starts a durable build and rejects duplicate builds and invalid skills", c do
    conn = build_conn() |> log_in_author(c.author)

    conn =
      post(
        conn,
        "/api/v1/interactives/#{c.project.slug}/#{c.activity.resource_id}/builds",
        c.params
      )

    assert %{"build" => %{"status" => "queued"}} = json_response(conn, 202)
    assert Repo.aggregate(Build, :count) == 1
    assert {:error, _} = Builds.start(c.project.slug, c.activity.resource_id, c.author, c.params)

    assert {:error, _} =
             Builds.start(c.project.slug, c.activity.resource_id, c.author, %{
               c.params
               | "selectedSkillIds" => [c.objective.resource.id]
             })

    assert {:error, :not_authorized} =
             Builds.latest(c.project.slug, c.activity.resource_id, author_fixture())
  end

  test "hosted function handoff downloads the completed-turn ZIP, uploads files and persists actual parts",
       c do
    {:ok, build} = Builds.start(c.project.slug, c.activity.resource_id, c.author, c.params)

    expect(MockHTTP, :request, fn :post, _, body, _, _ ->
      request = Jason.decode!(body)
      assert request["agent"]["model"] == "gpt-6-sol"
      assert request["agent"]["reasoning"]["effort"] == "low"
      assert hd(request["agent"]["tools"])["name"] == "finish_interactive"
      assert request["input"] =~ "Measure concentration"
      assert String.ends_with?(request["input"], c.params["prompt"])

      assert request["agent"]["instructions"] =~
               "/workspace/.agents/skills/build-interactive/SKILL.md"

      json(%{"id" => "sess_build"})
    end)

    assert {:snooze, 5} = Builds.advance(build.id, opts())

    action = %{
      "type" => "function_call",
      "name" => "finish_interactive",
      "turn_id" => "turn_1",
      "call_id" => "call_1",
      "arguments" => %{}
    }

    expect_reads(%{"status" => "requires_action", "required_actions" => [action]}, %{
      "id" => "turn_1",
      "status" => "waiting"
    })

    expect(MockHTTP, :request, fn :post, url, body, _, _ ->
      assert url =~ "/events"
      assert get_in(Jason.decode!(body), ["events", Access.at(0), "call_id"]) == "call_1"
      {:ok, %Response{status_code: 202, body: ""}}
    end)

    assert {:snooze, 5} = Builds.advance(build.id, opts())
    assert Repo.get!(Build, build.id).handoff["turn_id"] == "turn_1"

    # Completion must survive the author closing the editor and releasing its lock.
    assert {:ok} =
             Oli.Authoring.Locks.release(
               c.project.slug,
               c.publication.id,
               c.activity.resource_id,
               c.author.id
             )

    zip = archive(c.skill.resource.id)
    expect_completion(zip)

    expect(MockAws, :request, 2, fn operation ->
      assert operation.http_method == :put
      assert operation.path =~ "interactives/#{build.id}/"
      assert operation.headers["content-type"] in ["text/html", "application/json"]
      assert operation.headers["x-amz-server-side-encryption"] == "AES256"
      {:ok, %{status_code: 200}}
    end)

    expect_delete()
    assert :ok = Builds.advance(build.id, opts())
    assert Repo.get!(Build, build.id).status == "completed"
    revision = AuthoringResolver.from_resource_id(c.project.slug, c.activity.resource_id)
    assert revision.content["bundle"]["prefix"] == "interactives/#{build.id}"
    assert Enum.map(revision.content["authoring"]["parts"], & &1["id"]) == ["measure"]
    assert revision.objectives == %{"measure" => [c.skill.resource.id]}

    assert {:ok, %{activity: %{model: model}}} =
             Builds.latest(c.project.slug, c.activity.resource_id, c.author)

    assert model == revision.content

    assert Oli.Publishing.get_published_resource!(c.publication.id, c.activity.resource_id).locked_by_id ==
             nil
  end

  test "a stale build cannot replace newer author edits", c do
    {:ok, build} = Builds.start(c.project.slug, c.activity.resource_id, c.author, c.params)

    build
    |> Build.changeset(%{
      status: "running",
      session_id: "sess_build",
      handoff: %{"turn_id" => "turn_1"}
    })
    |> Repo.update!()

    revision = AuthoringResolver.from_resource_id(c.project.slug, c.activity.resource_id)
    changed = put_in(revision.content, ["authoring", "prompt"], "New author request")

    assert {:ok, _} =
             ActivityEditor.edit(
               c.project.slug,
               c.activity.resource_id,
               c.activity.resource_id,
               c.author.email,
               %{
                 "content" => Map.delete(changed, "authoring"),
                 "authoring" => changed["authoring"]
               }
             )

    expect_completion(archive(c.skill.resource.id))

    expect(MockAws, :request, 4, fn operation ->
      assert operation.http_method in [:put, :delete]
      {:ok, %{status_code: 200}}
    end)

    expect(MockHTTP, :request, fn :post, _, _, _, _ ->
      {:ok, %Response{status_code: 202, body: ""}}
    end)

    expect_delete(true)
    assert :ok = Builds.advance(build.id, opts())
    assert Repo.get!(Build, build.id).status == "failed"
    revision = AuthoringResolver.from_resource_id(c.project.slug, c.activity.resource_id)
    assert revision.content["authoring"]["prompt"] == "New author request"
    refute revision.content["bundle"]
  end

  test "ZIP validation rejects unsafe paths and parts mapped outside the selected skills", c do
    assert {:ok, _} = Bundle.unpack(archive(c.skill.resource.id), [c.skill.resource.id])
    assert {:error, _} = Bundle.unpack(archive(c.skill.resource.id), [999])

    assert {:error, _} =
             Bundle.unpack(archive(c.skill.resource.id, [{~c"../escape.js", "bad"}]), [
               c.skill.resource.id
             ])

    assert {:error, _} = Bundle.unpack("not a ZIP", [c.skill.resource.id])
  end

  test "revision loads current files into the hosted workspace and preserves original/history",
       c do
    source = completed_source(c)

    params =
      Map.merge(c.params, %{
        "prompt" => "Do not replace original",
        "revisionPrompt" => "Make the graph harder"
      })

    {:ok, build} = Builds.start(c.project.slug, c.activity.resource_id, c.author, params)
    assert build.inputs["source_build_id"] == source.id
    assert build.inputs["prompt"] == c.params["prompt"]
    assert build.inputs["revision_prompts"] == ["Make the graph harder"]

    {:ok, %{files: files}} = Bundle.unpack(archive(c.skill.resource.id), [c.skill.resource.id])

    expect(MockAws, :request, fn operation ->
      assert operation.http_method == :get
      assert operation.params["prefix"] == "interactives/#{source.id}/"

      {:ok,
       %{
         body: %{
           is_truncated: false,
           contents:
             Enum.map(files, fn {name, data} ->
               %{key: "interactives/#{source.id}/#{name}", size: byte_size(data)}
             end)
         }
       }}
    end)

    expect(MockAws, :request, map_size(files), fn operation ->
      name = operation.path |> String.split("/") |> List.last()
      {:ok, %{body: files[name]}}
    end)

    expect(MockHTTP, :request, fn :post, _, body, _, _ ->
      request = Jason.decode!(body)
      seeded = Map.new(request["environment"]["files"], &{&1["path"], Base.decode64!(&1["data"])})
      assert seeded["/workspace/app/index.html"] == files["index.html"]
      assert seeded["/workspace/app/manifest.json"] == files["manifest.json"]
      assert request["input"] =~ "Make the graph harder"
      assert request["input"] =~ c.params["prompt"]
      assert String.ends_with?(request["input"], "Make the graph harder")

      assert request["agent"]["instructions"] =~
               "/workspace/.agents/skills/revise-interactive/SKILL.md"

      assert seeded["/workspace/.agents/skills/revise-interactive/SKILL.md"]
      assert seeded["/workspace/.agents/skills/references/delivery-api.md"]
      assert seeded["/workspace/.agents/skills/references/authoring-contract.md"]
      json(%{"id" => "sess_build"})
    end)

    assert {:snooze, 5} = Builds.advance(build.id, opts())

    Repo.get!(Build, build.id)
    |> Build.changeset(%{handoff: %{"turn_id" => "turn_1"}})
    |> Repo.update!()

    # A debounced editor save may still carry the history from before Revise was clicked.
    pending = AuthoringResolver.from_resource_id(c.project.slug, c.activity.resource_id)

    {:ok, _} =
      ActivityEditor.edit(
        c.project.slug,
        c.activity.resource_id,
        c.activity.resource_id,
        c.author.email,
        %{
          "content" => Map.delete(pending.content, "authoring"),
          "authoring" => Map.put(pending.content["authoring"], "revision_prompts", [])
        }
      )

    expect_completion(archive(c.skill.resource.id))
    expect(MockAws, :request, 2, fn _ -> {:ok, %{status_code: 200}} end)
    expect_delete()
    assert :ok = Builds.advance(build.id, opts())
    revision = AuthoringResolver.from_resource_id(c.project.slug, c.activity.resource_id)
    assert revision.content["bundle"]["buildId"] == build.id
    assert revision.content["authoring"]["prompt"] == c.params["prompt"]
    assert revision.content["authoring"]["revision_prompt"] == ""
    assert revision.content["authoring"]["revision_prompts"] == ["Make the graph harder"]

    {:ok, next} =
      Builds.start(
        c.project.slug,
        c.activity.resource_id,
        c.author,
        Map.put(params, "revisionPrompt", "Add feedback")
      )

    assert next.inputs["revision_prompts"] == ["Make the graph harder", "Add feedback"]
  end

  test "a revision source failure preserves the previous bundle and requested change", c do
    source = completed_source(c)

    {:ok, build} =
      Builds.start(
        c.project.slug,
        c.activity.resource_id,
        c.author,
        Map.put(c.params, "revisionPrompt", "Add feedback")
      )

    expect(MockAws, :request, fn _ -> {:error, :unavailable} end)
    assert :ok = Builds.advance(build.id, opts())
    assert Repo.get!(Build, build.id).status == "failed"
    revision = AuthoringResolver.from_resource_id(c.project.slug, c.activity.resource_id)
    assert revision.content["bundle"]["buildId"] == source.id
    assert revision.content["authoring"]["revision_prompt"] == "Add feedback"
    assert revision.content["authoring"]["revision_prompts"] == ["Add feedback"]
  end

  test "queued cancellation prevents launch and permits another build", c do
    {:ok, build} = Builds.start(c.project.slug, c.activity.resource_id, c.author, c.params)

    assert {:ok, %{status: "cancelled"}} =
             Builds.cancel(c.project.slug, c.activity.resource_id, build.id, c.author, opts())

    assert :ok = Builds.advance(build.id, opts())
    path = "/api/v1/interactives/#{c.project.slug}/#{c.activity.resource_id}/builds/#{build.id}"
    conn = build_conn() |> log_in_author(c.author)

    assert %{"build" => %{"status" => "cancelled"}} =
             conn |> post(path <> "/cancel", %{version: 1}) |> json_response(202)

    stream =
      build_conn()
      |> log_in_author(c.author)
      |> Plug.Conn.put_req_header("accept", "text/event-stream")
      |> get(path <> "/events?_format=json")

    assert response(stream, 200) =~ "event: done"

    forbidden =
      build_conn() |> log_in_author(author_fixture()) |> get(path <> "/events?_format=json")

    assert json_response(forbidden, 403)["message"] == "Unauthorized"
    assert {:ok, _} = Builds.start(c.project.slug, c.activity.resource_id, c.author, c.params)

    assert {:error, :not_authorized} =
             Builds.cancel(
               c.project.slug,
               c.activity.resource_id,
               build.id,
               author_fixture(),
               opts()
             )

    assert {:error, :not_authorized} =
             Builds.get(c.project.slug, c.skill.resource.id, build.id, c.author)
  end

  test "cancellation stays fenced until provider cleanup succeeds and retains the draft", c do
    {:ok, build} = Builds.start(c.project.slug, c.activity.resource_id, c.author, c.params)
    build |> Build.changeset(%{status: "running", session_id: "sess_build"}) |> Repo.update!()
    expect(MockHTTP, :request, fn :post, _, _, _, _ -> {:error, :timeout} end)

    assert {:ok, %{status: "cancelling"}} =
             Builds.cancel(c.project.slug, c.activity.resource_id, build.id, c.author, opts())

    assert {:error, _} = Builds.start(c.project.slug, c.activity.resource_id, c.author, c.params)

    expect(MockHTTP, :request, fn :post, _, _, _, _ ->
      {:ok, %Response{status_code: 202, body: ""}}
    end)

    expect(MockHTTP, :request, fn :get, _, _, _, _ ->
      json(%{
        "data" => [
          %{
            "id" => "msg",
            "type" => "message",
            "role" => "assistant",
            "status" => "completed",
            "content" => [%{"type" => "output_text", "text" => "Building the lab"}]
          }
        ]
      })
    end)

    expect(MockHTTP, :request, fn :delete, _, _, _, _ -> json(%{"deleted" => true}) end)
    assert :ok = Builds.advance(build.id, opts())
    assert Repo.get!(Build, build.id).status == "cancelled"
    assert Repo.get!(Build, build.id).transcript == "Building the lab"
    revision = AuthoringResolver.from_resource_id(c.project.slug, c.activity.resource_id)
    refute revision.content["bundle"]
    assert revision.content["authoring"]["prompt"] == c.params["prompt"]
  end

  test "cancel during session creation cleans up the returned session instead of reviving the build",
       c do
    {:ok, build} = Builds.start(c.project.slug, c.activity.resource_id, c.author, c.params)

    expect(MockHTTP, :request, fn :post, _, _, _, _ ->
      assert {:ok, %{status: "cancelling"}} =
               Builds.cancel(c.project.slug, c.activity.resource_id, build.id, c.author, opts())

      json(%{"id" => "sess_build"})
    end)

    expect(MockHTTP, :request, fn :post, _, _, _, _ ->
      {:ok, %Response{status_code: 202, body: ""}}
    end)

    expect_delete(true)
    assert :ok = Builds.advance(build.id, opts())
    assert Repo.get!(Build, build.id).status == "cancelled"
    assert Repo.get!(Build, build.id).session_id == "sess_build"
  end

  test "cancellation while uploading cannot persist a completed bundle", c do
    source = completed_source(c)

    {:ok, build} =
      Builds.start(
        c.project.slug,
        c.activity.resource_id,
        c.author,
        Map.put(c.params, "revisionPrompt", "Add feedback")
      )

    build
    |> Build.changeset(%{
      status: "running",
      session_id: "sess_build",
      handoff: %{"turn_id" => "turn_1"}
    })
    |> Repo.update!()

    expect_completion(archive(c.skill.resource.id))

    expect(MockAws, :request, fn _ ->
      Repo.get!(Build, build.id) |> Build.changeset(%{status: "cancelling"}) |> Repo.update!()
      {:ok, %{status_code: 200}}
    end)

    expect(MockAws, :request, 3, fn _ -> {:ok, %{status_code: 200}} end)

    expect(MockHTTP, :request, fn :post, _, _, _, _ ->
      {:ok, %Response{status_code: 202, body: ""}}
    end)

    expect_delete(true)
    assert :ok = Builds.advance(build.id, opts())
    assert Repo.get!(Build, build.id).status == "cancelled"
    revision = AuthoringResolver.from_resource_id(c.project.slug, c.activity.resource_id)
    assert revision.content["bundle"]["buildId"] == source.id
    assert revision.content["authoring"]["revision_prompt"] == "Add feedback"
  end

  test "failed stream reconciliation preserves history already shown to the author", c do
    {:ok, build} = Builds.start(c.project.slug, c.activity.resource_id, c.author, c.params)

    build =
      build |> Build.changeset(%{status: "running", session_id: "sess_quiet"}) |> Repo.update!()

    expect(MockHTTP, :request, fn :get, _, _, _, _ ->
      json(%{
        "data" => [
          %{
            "id" => "prior",
            "type" => "message",
            "role" => "assistant",
            "status" => "completed",
            "content" => [%{"type" => "output_text", "text" => "Restored output"}]
          }
        ]
      })
    end)

    expect(MockHTTP, :request, fn :get, _, _, _, _ ->
      {:error, %HTTPoison.Error{reason: :timeout}}
    end)

    quiet_reader = fn _, _, opts ->
      opts[:on_open].()

      receive do
      after
        30_000 -> :closed
      end
    end

    emit = fn count, event, data ->
      case {event, count} do
        {"output", 2} ->
          assert data.text =~ "Restored output"
          {:error, :closed}

        {"output", _} ->
          {:ok, count + 1}

        _ ->
          {:ok, count}
      end
    end

    assert 2 =
             Oli.Interactives.Progress.follow(
               build,
               0,
               emit,
               opts() ++ [stream_reader: quiet_reader]
             )
  end

  defp completed_source(c) do
    {:ok, source} = Builds.start(c.project.slug, c.activity.resource_id, c.author, c.params)
    source |> Build.changeset(%{status: "completed"}) |> Repo.update!()
    revision = AuthoringResolver.from_resource_id(c.project.slug, c.activity.resource_id)
    model = Map.put(revision.content, "bundle", %{"buildId" => source.id})

    {:ok, _} =
      ActivityEditor.edit(
        c.project.slug,
        c.activity.resource_id,
        c.activity.resource_id,
        c.author.email,
        %{
          "content" => Map.delete(model, "authoring"),
          "authoring" => model["authoring"]
        }
      )

    source
  end

  defp opts, do: [api_key: "test-secret", http_client: MockHTTP]
  defp json(body), do: {:ok, %Response{status_code: 200, body: Jason.encode!(body)}}

  defp archive(skill, extra \\ []) do
    manifest = Jason.encode!(%{version: 1, parts: [%{id: "measure", objectiveIds: [skill]}]})

    {:ok, {_, zip}} =
      :zip.create(
        ~c"interactive.zip",
        [{~c"index.html", "<!doctype html><p>Lab</p>"}, {~c"manifest.json", manifest}] ++ extra,
        [:memory]
      )

    zip
  end

  defp expect_reads(session, turn) do
    expect(MockHTTP, :request, fn :get, url, _, _, _ ->
      assert url =~ "/sessions/sess_build"
      json(session)
    end)

    expect(MockHTTP, :request, fn :get, url, _, _, _ ->
      assert url =~ "/turns?"
      json(%{"data" => [turn]})
    end)
  end

  defp expect_completion(zip) do
    expect_reads(%{"status" => "idle", "required_actions" => []}, %{
      "id" => "turn_1",
      "status" => "completed"
    })

    expect(MockHTTP, :request, fn :get, url, _, _, _ ->
      assert url =~ "/artifacts?"

      json(%{
        "data" => [
          %{
            "id" => "artifact_1",
            "turn_id" => "turn_1",
            "path" => "/workspace/outputs/interactive.zip",
            "size_bytes" => byte_size(zip)
          }
        ],
        "has_more" => false
      })
    end)

    expect(MockHTTP, :request, fn :get, url, _, _, _ ->
      assert url =~ "/artifacts/artifact_1/content"
      {:ok, %Response{status_code: 200, body: zip}}
    end)

    expect_history()
  end

  defp expect_history do
    expect(MockHTTP, :request, fn :get, url, _, _, _ ->
      assert url =~ "/items?"
      json(%{"data" => [], "has_more" => false})
    end)
  end

  defp expect_delete(capture \\ false) do
    case capture do
      true -> expect_history()
      false -> :ok
    end

    expect(MockHTTP, :request, fn :delete, _, _, _, _ -> json(%{"deleted" => true}) end)
  end
end
