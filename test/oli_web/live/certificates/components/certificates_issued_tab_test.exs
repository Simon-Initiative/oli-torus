defmodule OliWeb.Certificates.Components.CertificatesIssuedTabTest do
  use OliWeb.ConnCase, async: true

  import LiveComponentTests
  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery.Certificates
  alias Oli.Repo.Paging
  alias Oli.Repo.Sorting

  alias OliWeb.Certificates.CertificatesIssuedTableModel
  alias OliWeb.Certificates.Components.CertificatesIssuedTab

  describe "certificates issued component" do
    setup [:setup_data]

    test "renders table", ctx do
      %{conn: conn, session_context: session_context, section: section} = ctx
      id = "certificates_issued_component"
      section_slug = section.slug
      section_id = section.id
      route_name = :authoring
      project = nil

      %{
        "direction" => direction,
        "limit" => limit,
        "offset" => offset,
        "sort_by" => sort_by,
        "text_search" => text_search
      } = params = CertificatesIssuedTab.decode_params(%{})

      paging = %Paging{offset: offset, limit: limit}
      sorting = %Sorting{field: sort_by, direction: direction}

      granted_certificates =
        Certificates.browse_granted_certificates(paging, sorting, text_search, section_id)

      table_model =
        CertificatesIssuedTableModel.new(session_context, granted_certificates, section_slug)

      attrs = %{
        id: id,
        params: params,
        section_slug: section_slug,
        table_model: table_model,
        ctx: session_context,
        route_name: route_name,
        project: project
      }

      {:ok, lcd, _html} = live_component_isolated(conn, CertificatesIssuedTab, attrs)

      ## Columns
      [{1, "Student"}, {2, "Issue Date"}, {3, "Issued By"}, {4, "ID"}]
      |> Enum.each(fn {i, column_title} ->
        assert has_element?(lcd, "table > thead > tr > th:nth-child(#{i})", column_title)
      end)

      %{
        recipient_1: recipient_1,
        recipient_2: recipient_2,
        recipient_3: recipient_3,
        author: author,
        instructor_1: instructor_1,
        instructor_2: instructor_2
      } = ctx

      ## Rows
      [
        {1, recipient_1.id, recipient_1.name, recipient_1.email, instructor_1.name},
        {2, recipient_2.id, recipient_2.name, recipient_2.email, author.name},
        {3, recipient_3.id, recipient_3.name, recipient_3.email, instructor_2.name}
      ]
      |> Enum.each(fn {i, recipient_id, recipient_name, recipient_email, instructor_name} ->
        # Recipient name
        assert has_element?(
                 lcd,
                 "table > tbody > tr:nth-child(#{i}) > td:nth-child(1) > div > a[href='/sections/#{section_slug}/student_dashboard/#{recipient_id}/content']",
                 recipient_name
               )

        # Recipient email
        assert has_element?(
                 lcd,
                 "table > tbody > tr:nth-child(#{i}) > td:nth-child(1) > div",
                 recipient_email
               )

        # Issuer name
        assert has_element?(
                 lcd,
                 "table > tbody > tr:nth-child(#{i}) > td:nth-child(3) > div",
                 instructor_name
               )
      end)
    end
  end

  def setup_data(%{}) do
    section = insert(:section)
    certificate = insert(:certificate, section: section)
    instructor_1 = insert(:user, name: "Instructor_1", given_name: nil, family_name: nil)
    instructor_2 = insert(:user, name: "Instructor_2", given_name: nil, family_name: nil)
    author = insert(:author, name: "Admin_1", given_name: nil, family_name: nil)

    recipient_1 = insert(:user, name: "Student_1", given_name: nil, family_name: nil)
    recipient_2 = insert(:user, name: "Student_2", given_name: nil, family_name: nil)
    recipient_3 = insert(:user, name: "Student_3", given_name: nil, family_name: nil)

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    a_minute_ago = DateTime.add(now, -60, :second)
    an_hour_ago = DateTime.add(now, -60, :minute)

    _gc_1 =
      insert(:granted_certificate,
        user: recipient_1,
        certificate: certificate,
        issued_by_type: :user,
        issued_by: instructor_1.id,
        issued_at: now
      )

    _gc_2 =
      insert(:granted_certificate,
        user: recipient_2,
        certificate: certificate,
        issued_by_type: :author,
        issued_by: author.id,
        issued_at: a_minute_ago
      )

    _gc_3 =
      insert(:granted_certificate,
        user: recipient_3,
        certificate: certificate,
        issued_by_type: :user,
        issued_by: instructor_2.id,
        issued_at: an_hour_ago
      )

    limit = 25
    offset = 0
    direction = :asc
    field = :issuer

    paging = %Paging{limit: limit, offset: offset}
    sorting = %Sorting{direction: direction, field: field}

    session_context = %OliWeb.Common.SessionContext{
      browser_timezone: "utc",
      local_tz: "utc",
      author: nil,
      user: nil,
      is_liveview: true
    }

    %{
      recipient_1: recipient_1,
      recipient_2: recipient_2,
      recipient_3: recipient_3,
      instructor_1: instructor_1,
      instructor_2: instructor_2,
      author: author,
      session_context: session_context,
      paging: paging,
      sorting: sorting,
      section: section
    }
  end
end
