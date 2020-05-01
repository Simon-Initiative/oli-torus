defmodule OliWeb.StudentDeliveryView do
  use OliWeb, :view

  def page_link(conn, context_id, slug) do
    Routes.student_delivery_path(conn, :page, context_id, slug)
  end
end
