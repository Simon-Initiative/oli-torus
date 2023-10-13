defmodule Oli.Qa.Reviewers.Content.SelectionWorker do
  use Oban.Worker, queue: :selections

  alias Oli.Qa.{Warnings, Reviews}
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.Result

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "review_id" => review_id
          } = args
      }) do
    Reviews.get_review!(review_id)
    |> do_perform(args)
  end

  # This handles the case that if by the time this job executes
  # the original review no longer exists, then we simply do nothing
  defp do_perform(nil, _), do: :ok

  defp do_perform(review, %{
         "selection" => selection,
         "revision_id" => revision_id,
         "project_slug" => project_slug,
         "publication_id" => publication_id,
         "review_id" => review_id
       }) do
    case Oli.Activities.Realizer.Selection.parse(selection) do
      {:ok, selection} ->
        case Oli.Activities.Realizer.Selection.test(
               selection,
               %Source{
                 publication_id: publication_id,
                 blacklisted_activity_ids: [],
                 section_slug: ""
               }
             ) do
          {:ok, _} ->
            :ok

          {:partial, %Result{totalCount: total}} ->
            create_warning(
              review_id,
              revision_id,
              project_slug,
              selection,
              "Activity bank selection only returned #{total} of #{selection.count} activities"
            )
        end

      {:error, "no values provided for expression"} ->
        create_warning(
          review.id,
          revision_id,
          project_slug,
          selection,
          "No value provided for criteria in bank selection logic"
        )

      _ ->
        create_warning(
          review.id,
          revision_id,
          project_slug,
          selection,
          "Invalid bank selection logic"
        )
    end
  end

  defp create_warning(review_id, revision_id, project_slug, selection, problem) do
    {:ok, warning} =
      Warnings.create_warning(%{
        review_id: review_id,
        revision_id: revision_id,
        subtype: problem,
        content: Map.put(selection, :type, "selection")
      })

    Oli.Authoring.Broadcaster.broadcast_new_warning(warning.id, project_slug)

    :ok
  end
end
