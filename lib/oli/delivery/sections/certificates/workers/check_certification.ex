defmodule Oli.Delivery.Sections.Certificates.Workers.CheckCertification do
  use Oban.Worker,
    queue: :certificate_eligibility,
    unique: [keys: [:user_id, :section_id]],
    max_attempts: 1

  alias Oli.Delivery.GrantedCertificates
  alias Oli.Delivery.Sections.Certificates.Workers.CheckCertification

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "section_id" => section_id}}) do
    GrantedCertificates.has_qualified(user_id, section_id)

    :ok
  end

  def restart_certificate_check(user_id, section_id) do
    Ecto.Adapters.SQL.query!(
      Oli.Repo,
      """
      DELETE FROM oban_jobs
      WHERE id = (
        SELECT id FROM oban_jobs
        WHERE queue = 'certificate_eligibility'
        AND args @> $1
        LIMIT 1
      )
      """,
      [%{"user_id" => user_id, "section_id" => section_id}]
    )

    %{user_id: user_id, section_id: section_id} |> CheckCertification.new() |> Oban.insert()
  end
end
