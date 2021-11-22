defmodule OliWeb.ActivityBankView do
  use OliWeb, :view

  alias OliWeb.Router.Helpers, as: Routes

  def render_activity(activity, activity_type, section_slug) do
    tag = activity_type.authoring_element

    "<#{tag} model=\"#{activity.encoded_model}\" editmode=\"false\" projectSlug=\"#{section_slug}\"></#{tag}>"
  end

  def page_url(conn, offset) do
    %{
      section_slug: section_slug,
      revision_slug: revision_slug,
      selection_id: selection_id
    } = conn.assigns

    Routes.activity_bank_path(conn, :preview, section_slug, revision_slug, selection_id,
      offset: offset
    )
  end
end
