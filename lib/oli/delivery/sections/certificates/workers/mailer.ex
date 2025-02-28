defmodule Oli.Delivery.Sections.Certificates.Workers.Mailer do
  use Oban.Worker, queue: :certificate_mailer, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    ### TODO: MER-4107
    :ok
  end
end
