defmodule Oli.Delivery.Updates.Worker do
  @moduledoc """
  An Oban driven update worker that applies a publication to a section through
  `Oli.Delivery.Sections.Audited.apply_publication_update/3`.

  The job carries the audit context of whoever started the update (see `args/3`), and its
  event records that actor with source `:job`, linked to the operation that enqueued it. Jobs
  enqueued without one, before the context was carried, record the `scheduled_maintenance`
  system actor.
  """
  use Oban.Worker, queue: :updates, max_attempts: 3

  alias Oli.Auditing.Context
  alias Oli.Delivery.Sections.Audited, as: SectionsAudited

  @doc "The arguments of a job that applies `publication_id` to the section with `section_slug`."
  @spec args(String.t(), pos_integer(), Context.t()) :: map()
  def args(section_slug, publication_id, %Context{} = context) do
    %{
      "section_slug" => section_slug,
      "publication_id" => publication_id,
      "audit_context" => Context.to_job_args(context)
    }
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"section_slug" => section_slug, "publication_id" => publication_id} = args
      }) do
    case job_context(args) do
      {:ok, context} -> perform_now(context, section_slug, publication_id)
      :error -> {:cancel, :invalid_audit_context}
    end
  end

  @doc "Applies `publication_id` to the section with `section_slug` as `context`."
  def perform_now(%Context{} = context, section_slug, publication_id) do
    section = Oli.Delivery.Sections.get_section_by_slug(section_slug)
    SectionsAudited.apply_publication_update(context, section, publication_id)
  end

  defp job_context(%{"audit_context" => audit_context}), do: Context.from_job_args(audit_context)

  defp job_context(_args),
    do: {:ok, Context.for_system(:scheduled_maintenance, source: :job)}
end
