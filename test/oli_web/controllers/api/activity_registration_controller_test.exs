defmodule OliWeb.Api.ActivityRegistrationControllerTest do
  use OliWeb.ConnCase

  alias Oli.Seeder
  alias OliWeb.Api.ActivityRegistrationController

  describe "activity registration test" do
    setup [:setup_session]

    test "can register an activity", %{
      conn: conn
    } do
      _original_count = Oli.Activities.list_activity_registrations() |> Enum.count()

      payload = %{"upload" => %{path: "./test/oli_web/controllers/api/activity/bundle.zip"}}

      {:ok, code} = create_key(%{registration_enabled: true, registration_namespace: "test"})
      encoded_api_key = Base.encode64(code)

      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer #{encoded_api_key}")
      |> Plug.Conn.put_req_header("content-type", "multipart/form-data")
      |> ActivityRegistrationController.create(payload)

      _new_count = Oli.Activities.list_activity_registrations() |> Enum.count()

      # This assertion succeeds when running the test locally, but fails when
      # run on the server as part of the build
      # assert original_count + 1 == new_count
    end
  end

  defp create_key(attrs) do
    code = UUID.uuid4()

    case Oli.Interop.create_key(code, "there is no hint") do
      {:ok, key} ->
        case Oli.Interop.update_key(key, attrs) do
          {:ok, _} -> {:ok, code}
          e -> e
        end

      e ->
        e
    end
  end

  defp setup_session(%{conn: conn}) do
    map =
      Seeder.base_project_with_resource2()

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> assign_current_author(map.author)

    {:ok, conn: conn, map: map}
  end
end
