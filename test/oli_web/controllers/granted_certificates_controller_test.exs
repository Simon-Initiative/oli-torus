defmodule OliWeb.GrantedCertificatesControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory
  alias Oli.Authoring.Course

  defp project_slug(%{base_project: %{slug: slug}}), do: slug
  defp project_slug(%{base_project_id: id}), do: Course.get_project!(id).slug

  describe "download_granted_certificates" do
    test "returns a csv with the granted certificates - state = earned - of the provided product id",
         %{conn: conn} do
      {:ok, conn: conn, author: _} = author_conn(%{conn: conn})
      product = insert(:section, type: :blueprint)
      section = insert(:section, type: :enrollable, blueprint_id: product.id)
      certificate = insert(:certificate, section: section)
      [gc_1, gc_2] = insert_pair(:granted_certificate, certificate: certificate, state: :earned)
      [gc_3, gc_4] = insert_pair(:granted_certificate, certificate: certificate, state: :denied)

      project_slug = project_slug(product)

      conn =
        get(
          conn,
          ~p"/workspaces/course_author/#{project_slug}/products/#{product.id}/downloads/granted_certificates"
        )

      assert response(conn, 200)

      assert Enum.any?(conn.resp_headers, fn h ->
               h ==
                 {"content-disposition",
                  "attachment; filename="#{product.id}_granted_certificates_content.csv""}
             end)

      assert Enum.any?(conn.resp_headers, fn h -> h == {"content-type", "text/csv"} end)
      assert conn.resp_body =~ "student_name,student_email,issued_at,issuer_name,guid"

      assert conn.resp_body =~ gc_1.user.given_name
      assert conn.resp_body =~ gc_2.user.given_name
      refute conn.resp_body =~ gc_3.user.given_name
      refute conn.resp_body =~ gc_4.user.given_name
    end
  end
end
