defmodule OliWeb.SpotCheckController do
  use OliWeb, :controller

  import Ecto.Query, warn: false

  def index(conn, %{"activity_attempt_id" => attempt_id}) do

    {section_slug, attempt_guid} =
      from(a in Oli.Delivery.Attempts.Core.ActivityAttempt,
        join: r in Oli.Delivery.Attempts.Core.ResourceAttempt,
        on: a.resource_attempt_id == r.id,
        join: ra in Oli.Delivery.Attempts.Core.ResourceAccess,
        on: r.resource_access_id == ra.id,
        join: s in Oli.Delivery.Sections.Section,
        on: s.id == ra.section_id,
        where: a.id == ^attempt_id,
        select: {s.slug, r.attempt_guid}
      )
      |> Oli.Repo.one()

    conn
    |> redirect(
      to: Routes.instructor_review_path(conn, :review_attempt, section_slug, attempt_guid)
    )
  end

end
