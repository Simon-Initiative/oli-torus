defmodule OliWeb.ActivityBankView do
  use OliWeb, :view

  alias OliWeb.Router.Helpers, as: Routes

  def render_activity(activity, activity_type, section_slug) do
    tag = activity_type.authoring_element

    "<#{tag} model=\"#{activity.encoded_model}\" editmode=\"false\" projectSlug=\"#{section_slug}\"></#{tag}>"
  end
end
