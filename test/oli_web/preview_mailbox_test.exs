defmodule OliWeb.PreviewMailboxTest do
  use OliWeb.ConnCase, async: false

  alias Swoosh.Adapters.Local.Storage.Memory

  # Compile isolated copies of the real configuration and router with the
  # preview marker. The application's test artifact remains non-preview.
  @preview_router OliWeb.MailboxTestRouter

  setup_all do
    previous = Application.get_env(:oli, :preview_qa_tools)
    Application.put_env(:oli, :preview_qa_tools, preview_build?: true)

    try do
      for path <- [
            "lib/oli/preview_qa_tools/config.ex",
            "lib/oli_web/router.ex"
          ] do
        path
        |> File.read!()
        |> String.replace("Oli.PreviewQATools.Config", "Oli.PreviewQATools.MailboxTestConfig")
        |> String.replace("defmodule OliWeb.Router do", "defmodule #{@preview_router} do")
        |> Code.compile_string(path)
      end
    after
      case previous do
        nil -> Application.delete_env(:oli, :preview_qa_tools)
        value -> Application.put_env(:oli, :preview_qa_tools, value)
      end
    end

    :ok
  end

  setup do
    previous = System.get_env("PREVIEW_QA_TOOLS_ENABLED")
    System.put_env("PREVIEW_QA_TOOLS_ENABLED", "true")
    Memory.delete_all()

    on_exit(fn ->
      Memory.delete_all()

      case previous do
        nil -> System.delete_env("PREVIEW_QA_TOOLS_ENABLED")
        value -> System.put_env("PREVIEW_QA_TOOLS_ENABLED", value)
      end
    end)

    :ok
  end

  test "mailbox is accessible without Torus authentication in a preview build with QA tools enabled" do
    assert html_response(request("/dev/mailbox"), 200)
    assert json_response(request("/dev/mailbox/json"), 200)["data"] == []
  end

  test "mailbox is unavailable in a preview build when QA tools are disabled or unset" do
    for value <- ["false", nil] do
      case value do
        nil -> System.delete_env("PREVIEW_QA_TOOLS_ENABLED")
        value -> System.put_env("PREVIEW_QA_TOOLS_ENABLED", value)
      end

      for path <- ["/dev/mailbox", "/dev/mailbox/json"] do
        assert response(request(path), 404) == "Not Found"
      end
    end
  end

  test "mailbox is unavailable outside a preview build regardless of the QA tools flag" do
    for value <- ["true", "false", nil] do
      case value do
        nil -> System.delete_env("PREVIEW_QA_TOOLS_ENABLED")
        value -> System.put_env("PREVIEW_QA_TOOLS_ENABLED", value)
      end

      for path <- ["/dev/mailbox", "/dev/mailbox/json"] do
        error =
          assert_raise Phoenix.Router.NoRouteError, fn ->
            request(path, OliWeb.Router)
          end

        assert error.plug_status == 404
      end
    end
  end

  defp request(path, router \\ @preview_router) do
    conn =
      build_conn(:get, path)
      |> Plug.Test.init_test_session(%{})
      |> put_private(:phoenix_endpoint, OliWeb.Endpoint)

    router.call(conn, router.init([]))
  end
end
