defmodule OliWeb.Plugs.RestrictLmsUserAccessTest do
  use ExUnit.Case, async: true

  import Plug.Conn

  alias OliWeb.Plugs.RestrictLmsUserAccess
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section

  describe "call/2" do
    test "redirects LMS users away from non-LMS sections" do
      conn =
        "GET"
        |> Plug.Test.conn("/sections/intro/enroll?step=1")
        |> assign(:current_user, %User{independent_learner: false})
        |> assign(:section, %Section{title: "Intro Course", lti_1p3_deployment_id: nil})

      conn = RestrictLmsUserAccess.call(conn, %{})

      assert conn.halted
      assert conn.status == 302

      [location] = get_resp_header(conn, "location")
      assert %URI{path: "/lms_user_instructions", query: query} = URI.parse(location)

      params = URI.decode_query(query)
      assert params["section_title"] == "Intro Course"
      assert params["request_path"] == "/sections/intro/enroll?step=1"
    end

    test "allows access when user is independent" do
      conn =
        "GET"
        |> Plug.Test.conn("/sections/intro/enroll")
        |> assign(:current_user, %User{independent_learner: true})
        |> assign(:section, %Section{title: "Intro Course", lti_1p3_deployment_id: nil})

      conn = RestrictLmsUserAccess.call(conn, %{})

      refute conn.halted
      refute get_resp_header(conn, "location") |> Enum.any?()
    end

    test "allows access when section is LMS backed" do
      conn =
        "GET"
        |> Plug.Test.conn("/sections/lms/enroll")
        |> assign(:current_user, %User{independent_learner: false})
        |> assign(:section, %Section{title: "LMS Course", lti_1p3_deployment_id: 123})

      conn = RestrictLmsUserAccess.call(conn, %{})

      refute conn.halted
      refute get_resp_header(conn, "location") |> Enum.any?()
    end
  end
end
