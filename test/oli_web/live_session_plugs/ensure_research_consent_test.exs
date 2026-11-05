defmodule OliWeb.LiveSessionPlugs.EnsureResearchConsentTest do
  use OliWeb.ConnCase, async: true

  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias OliWeb.LiveSessionPlugs.EnsureResearchConsent

  test "redirects a student with no answer when the section requires consent" do
    socket = student_socket(nil)

    assert {:halt, redirected_socket} =
             EnsureResearchConsent.on_mount(:default, %{}, %{}, socket)

    assert {:redirect, %{to: to}} = redirected_socket.redirected

    assert to ==
             "/research_consent?" <>
               URI.encode_query(%{"user_return_to" => "/sections/#{socket.assigns.section.slug}"})
  end

  for preference <- [true, false] do
    test "allows a student who answered with research_opt_out #{preference}" do
      socket = student_socket(unquote(preference))

      assert {:cont, ^socket} = EnsureResearchConsent.on_mount(:default, %{}, %{}, socket)
    end
  end

  test "allows a student with no answer when the section disables the consent form" do
    socket = student_socket(nil, :no_form)

    assert {:cont, ^socket} = EnsureResearchConsent.on_mount(:default, %{}, %{}, socket)
  end

  test "instructor role does not bypass a required consent form" do
    user = insert(:user, research_opt_out: nil)
    section = insert(:section, institution: insert(:institution, research_consent: :oli_form))
    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])
    socket = socket_for(user, section)

    assert {:halt, redirected_socket} = EnsureResearchConsent.on_mount(:default, %{}, %{}, socket)
    assert {:redirect, %{to: "/research_consent?" <> _}} = redirected_socket.redirected
  end

  test "admin access does not require a delivery user or a consent answer", %{conn: conn} do
    section = insert(:section)

    conn =
      conn
      |> assign(:current_user, nil)
      |> assign(:is_admin, true)
      |> assign(:section, section)

    refute Oli.Plugs.EnsureResearchConsent.call(conn, []).halted

    socket = %Phoenix.LiveView.Socket{assigns: Map.put(conn.assigns, :__changed__, %{})}
    assert {:cont, ^socket} = EnsureResearchConsent.on_mount(:default, %{}, %{}, socket)
  end

  test "being an instructor in a different section does not bypass the student form" do
    user = insert(:user, research_opt_out: nil)
    instructor_section = insert(:section)

    student_section =
      insert(:section, institution: insert(:institution, research_consent: :oli_form))

    Sections.enroll(user.id, instructor_section.id, [ContextRoles.get_role(:context_instructor)])
    Sections.enroll(user.id, student_section.id, [ContextRoles.get_role(:context_learner)])

    socket = socket_for(user, student_section)

    assert {:halt, socket} = EnsureResearchConsent.on_mount(:default, %{}, %{}, socket)
    assert {:redirect, %{to: "/research_consent?" <> _}} = socket.redirected
  end

  defp student_socket(preference, setting \\ :oli_form) do
    user = insert(:user, research_opt_out: preference)
    section = insert(:section, institution: insert(:institution, research_consent: setting))
    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

    socket_for(user, section)
  end

  defp socket_for(user, section) do
    %Phoenix.LiveView.Socket{
      endpoint: OliWeb.Endpoint,
      assigns: %{__changed__: %{}, current_user: user, section: section, is_admin: false}
    }
  end
end
