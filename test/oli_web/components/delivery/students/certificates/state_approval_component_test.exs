defmodule OliWeb.Components.Delivery.Students.Certificates.StateApprovalComponentTest do
  use OliWeb.ConnCase, async: true
  use Oban.Testing, repo: Oli.Repo

  import LiveComponentTests
  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.GrantedCertificates
  alias Oli.Delivery.Sections.Certificate
  alias Oli.Delivery.Sections.Certificates.Workers.GeneratePdf
  alias Oli.Delivery.Sections.GrantedCertificate
  alias Oli.Repo
  alias OliWeb.Components.Delivery.Students.Certificates.StateApprovalComponent

  describe "State approval component" do
    setup do
      section = insert(:section, certificate_enabled: true)
      certificate = insert(:certificate, section: section)
      student = insert(:user)
      student_in_progress = insert(:user)
      granted_certificate = insert(:granted_certificate, certificate: certificate, user: student)
      instructor = insert(:user)

      %{
        section: section,
        certificate: certificate,
        student: student,
        student_in_progress: student_in_progress,
        instructor: instructor,
        granted_certificate: granted_certificate
      }
    end

    test "renders the aprove/deny buttons when granted certificate state = :pending", %{
      conn: conn,
      certificate: certificate,
      granted_certificate: granted_certificate,
      student: student,
      instructor: instructor
    } do
      certificate = update_certificate(certificate, %{requires_instructor_approval: true})
      granted_certificate = update_granted_certificate(granted_certificate, %{state: :pending})

      attrs = %{
        id: "certificate-state-component",
        module: StateApprovalComponent,
        certificate_status: granted_certificate.state,
        requires_instructor_approval: certificate.requires_instructor_approval,
        granted_certificate_id: granted_certificate.id,
        certificate_id: certificate.id,
        student: student,
        issued_by_type: :user,
        issued_by_id: instructor.id
      }

      {:ok, lcd, _html} = live_component_isolated(conn, StateApprovalComponent, attrs)
      assert has_element?(lcd, "div[role='approve or deny buttons']")
    end

    test "renders the aprove/deny buttons when instructor clicks on `edit` icon", %{
      conn: conn,
      certificate: certificate,
      granted_certificate: granted_certificate,
      student: student,
      instructor: instructor
    } do
      attrs = %{
        id: "certificate-state-component",
        module: StateApprovalComponent,
        certificate_status: granted_certificate.state,
        requires_instructor_approval: certificate.requires_instructor_approval,
        granted_certificate_id: granted_certificate.id,
        certificate_id: certificate.id,
        student: student,
        issued_by_type: :user,
        issued_by_id: instructor.id
      }

      {:ok, lcd, _html} = live_component_isolated(conn, StateApprovalComponent, attrs)

      refute has_element?(lcd, "div[role='approve or deny buttons']")

      lcd
      |> element("button[phx-click=edit_certificate_status]")
      |> render_click()

      assert has_element?(lcd, "div[role='approve or deny buttons']")
    end

    test "renders 'In Progress' label when the student has not yet met all the thresholds (there is no granted_certificate)",
         %{
           conn: conn,
           certificate: certificate,
           student: student,
           instructor: instructor
         } do
      attrs = %{
        id: "certificate-state-component",
        module: StateApprovalComponent,
        certificate_status: nil,
        requires_instructor_approval: certificate.requires_instructor_approval,
        granted_certificate_id: nil,
        certificate_id: certificate.id,
        student: student,
        platform_name: "Oli Torus",
        course_name: "Some Course Name",
        instructor_email: instructor.email,
        issued_by_type: :user,
        issued_by_id: instructor.id
      }

      {:ok, lcd, _html} = live_component_isolated(conn, StateApprovalComponent, attrs)

      assert has_element?(lcd, "div[role='in progress status']", "In Progress")
    end

    test "renders 'Approved' label when the student has already earned the certificate",
         %{
           conn: conn,
           granted_certificate: granted_certificate,
           certificate: certificate,
           student: student,
           instructor: instructor
         } do
      attrs = %{
        id: "certificate-state-component",
        module: StateApprovalComponent,
        certificate_status: granted_certificate.state,
        requires_instructor_approval: certificate.requires_instructor_approval,
        granted_certificate_id: granted_certificate.id,
        certificate_id: certificate.id,
        student: student,
        platform_name: "Oli Torus",
        course_name: "Some Course Name",
        instructor_email: instructor.email,
        issued_by_type: :user,
        issued_by_id: instructor.id
      }

      {:ok, lcd, _html} = live_component_isolated(conn, StateApprovalComponent, attrs)

      assert has_element?(lcd, "div[role='approved status']", "Approved")
    end

    test "renders 'Denied' label when the student's certificate has been denied",
         %{
           conn: conn,
           granted_certificate: granted_certificate,
           certificate: certificate,
           student: student,
           instructor: instructor
         } do
      granted_certificate = update_granted_certificate(granted_certificate, %{state: :denied})

      attrs = %{
        id: "certificate-state-component",
        module: StateApprovalComponent,
        certificate_status: granted_certificate.state,
        requires_instructor_approval: certificate.requires_instructor_approval,
        granted_certificate_id: granted_certificate.id,
        certificate_id: certificate.id,
        student: student,
        platform_name: "Oli Torus",
        course_name: "Some Course Name",
        instructor_email: instructor.email,
        issued_by_type: :user,
        issued_by_id: instructor.id
      }

      {:ok, lcd, _html} = live_component_isolated(conn, StateApprovalComponent, attrs)

      assert has_element?(lcd, "div[role='denied status']", "Denied")
    end

    test "can edit an existing granted certificate state", %{
      conn: conn,
      granted_certificate: granted_certificate,
      certificate: certificate,
      student: student,
      instructor: instructor
    } do
      granted_certificate =
        update_granted_certificate(granted_certificate, %{
          state: :denied,
          url: "some_initial_url",
          student_email_sent: true
        })

      previous_gc_guid = granted_certificate.guid

      attrs = %{
        id: "certificate-state-component",
        module: StateApprovalComponent,
        certificate_status: granted_certificate.state,
        requires_instructor_approval: certificate.requires_instructor_approval,
        granted_certificate_id: granted_certificate.id,
        certificate_id: certificate.id,
        student: student,
        platform_name: "Oli Torus",
        course_name: "Some Course Name",
        instructor_email: instructor.email,
        issued_by_type: :user,
        issued_by_id: instructor.id
      }

      {:ok, lcd, _html} = live_component_isolated(conn, StateApprovalComponent, attrs)

      ## from denied to approved
      assert granted_certificate.state == :denied

      lcd
      |> element("button[phx-click=edit_certificate_status]")
      |> render_click()

      lcd
      |> element("button[phx-value-required_state=earned]", "Approve")
      |> render_click()

      granted_certificate = Repo.get_by!(GrantedCertificate, id: granted_certificate.id)

      assert granted_certificate.state == :earned
      refute granted_certificate.url
      refute granted_certificate.student_email_sent
      assert previous_gc_guid != granted_certificate.guid
      assert has_element?(lcd, "div[role='approved status']", "Approved")

      assert_enqueued(
        worker: GeneratePdf,
        args: %{"granted_certificate_id" => granted_certificate.id, "send_email?" => false}
      )

      previous_gc_guid = granted_certificate.guid

      ## from approved to denied
      lcd
      |> element("button[phx-click=edit_certificate_status]")
      |> render_click()

      lcd
      |> element("button[phx-value-required_state=denied]", "Deny")
      |> render_click()

      granted_certificate = Repo.get_by!(GrantedCertificate, id: granted_certificate.id)

      assert granted_certificate.state == :denied
      refute granted_certificate.url
      refute granted_certificate.student_email_sent
      assert previous_gc_guid != granted_certificate.guid
      assert has_element?(lcd, "div[role='denied status']", "Denied")
    end

    test "can edit a non existing granted certificate ('In Progress')", %{
      conn: conn,
      certificate: certificate,
      student_in_progress: student,
      instructor: instructor
    } do
      attrs = %{
        id: "certificate-state-component",
        module: StateApprovalComponent,
        certificate_status: nil,
        requires_instructor_approval: certificate.requires_instructor_approval,
        granted_certificate_id: nil,
        certificate_id: certificate.id,
        student: student,
        platform_name: "Oli Torus",
        course_name: "Some Course Name",
        instructor_email: instructor.email,
        issued_by_type: :user,
        issued_by_id: instructor.id
      }

      granted_certificate =
        user_granted_certificate(certificate.id, student.id)

      {:ok, lcd, _html} = live_component_isolated(conn, StateApprovalComponent, attrs)

      refute granted_certificate

      ## from "In Progress" to approved

      lcd
      |> element("button[phx-click=edit_certificate_status]")
      |> render_click()

      lcd
      |> element("button[phx-value-required_state=earned]", "Approve")
      |> render_click()

      granted_certificate = user_granted_certificate(certificate.id, student.id)

      assert granted_certificate.state == :earned
      assert has_element?(lcd, "div[role='approved status']", "Approved")
      refute granted_certificate.student_email_sent

      assert_enqueued(
        worker: GeneratePdf,
        args: %{"granted_certificate_id" => granted_certificate.id, "send_email?" => false}
      )

      ## from approved to denied
      lcd
      |> element("button[phx-click=edit_certificate_status]")
      |> render_click()

      lcd
      |> element("button[phx-value-required_state=denied]", "Deny")
      |> render_click()

      granted_certificate = user_granted_certificate(certificate.id, student.id)

      assert granted_certificate.state == :denied
      assert has_element?(lcd, "div[role='denied status']", "Denied")
    end
  end

  defp update_certificate(certificate, attrs) do
    {:ok, certificate} =
      certificate
      |> Certificate.changeset(attrs)
      |> Repo.update()

    certificate
  end

  defp update_granted_certificate(granted_certificate, attrs) do
    {:ok, granted_certificate} =
      GrantedCertificates.update_granted_certificate(granted_certificate.id, attrs)

    granted_certificate
  end

  defp user_granted_certificate(nil, _user_id), do: nil

  defp user_granted_certificate(certificate_id, user_id) do
    Repo.get_by(GrantedCertificate, certificate_id: certificate_id, user_id: user_id)
  end
end
