defmodule Oli.GoogleDocs.ClientTest do
  use ExUnit.Case, async: false

  alias HTTPoison.Response
  alias Oli.GoogleDocs.Client

  setup context do
    original = Application.get_env(:oli, :http_client)

    responses = Map.get(context, :responses, [])
    {:ok, _pid} = RedirectHTTPStub.start_link(responses)

    Application.put_env(:oli, :http_client, RedirectHTTPStub)

    on_exit(fn ->
      RedirectHTTPStub.stop()

      if original do
        Application.put_env(:oli, :http_client, original)
      else
        Application.delete_env(:oli, :http_client)
      end
    end)

    :ok
  end

  describe "fetch_markdown/2" do
    @tag responses: [
           {:ok,
            %Response{
              status_code: 307,
              headers: [
                {"Location",
                 "https://doc-00-ag-docstext.googleusercontent.com/export/some/path?format=md"}
              ]
            }},
           {:ok,
            %Response{
              status_code: 200,
              body: "content",
              headers: [{"content-type", "text/markdown"}]
            }}
         ]
    test "follows googleusercontent redirect" do
      assert {:ok, %{body: "content"}} = Client.fetch_markdown("1RedirectDoc", [])
      assert RedirectHTTPStub.calls() == 2
    end

    @tag responses: [
           {:ok,
            %Response{
              status_code: 307,
              headers: [{"Location", "https://accounts.google.com"}]
            }}
         ]
    test "returns redirect error when location not allowed" do
      assert {:error, {:http_redirect, 307, "https://accounts.google.com"}} =
               Client.fetch_markdown("1RedirectDoc", [])

      assert RedirectHTTPStub.calls() == 1
    end
  end
end

defmodule RedirectHTTPStub do
  use Agent

  def start_link(responses) do
    stop()
    Agent.start_link(fn -> {responses, 0} end, name: __MODULE__)
  end

  def stop do
    case Process.whereis(__MODULE__) do
      nil ->
        :ok

      pid ->
        try do
          Agent.stop(pid)
        catch
          :exit, {:noproc, _} -> :ok
        end
    end
  end

  def get(_url, _headers, _opts) do
    Agent.get_and_update(__MODULE__, fn
      {[], count} ->
        {{:error, :no_more_responses}, {[], count}}

      {[response | rest], count} ->
        {response, {rest, count + 1}}
    end)
  end

  def calls do
    Agent.get(__MODULE__, fn {_responses, count} -> count end)
  end
end
