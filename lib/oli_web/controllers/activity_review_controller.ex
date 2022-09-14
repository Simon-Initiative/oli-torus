defmodule OliWeb.ActivityReviewController do
  use OliWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html",
      scripts: Oli.Activities.get_activity_scripts(),
      title: "Activity Review"
    )
  end
end
