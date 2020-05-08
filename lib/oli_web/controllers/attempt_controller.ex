defmodule OliWeb.AttemptController do
  use OliWeb, :controller

  def save(conn, %{"contextId" => context_id, "resourceSlug" => resource_slug, "activitySlug" => activity_slug, "payload" => payload}) do

    # user_id = conn.assigns[:current_user_id]
    IO.inspect payload
    IO.inspect context_id
    IO.inspect resource_slug
    IO.inspect activity_slug

    json conn, %{ "type" => "success"}
  end

end
