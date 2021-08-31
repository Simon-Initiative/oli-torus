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

  defp do_perform(nil, _), do: :ok

  defp do_perform(review, %{
         "selection" => selection,
         "revision_id" => revision_id,
         "publication_id" => publication_id,
         "review_id" => review_id
       }) do
    case Oli.Activities.Realizer.Selection.parse(selection) do
      {:ok, selection} ->
        case Oli.Activities.Realizer.Selection.test(selection, %Source{
               publication_id: publication_id,
               blacklisted_activity_ids: [],
               section_slug: ""
             }) do
          {:ok, _} ->
            :ok

          {:partial, %Result{totalCount: total}} ->
            num_missing = selection.count - total

            create_warning(
              review_id,
              revision_id,
              selection,
              "#{num_missing} of #{selection.count} selection(s) could not be fulfilled for bank selection"
            )
        end

      _ ->
        create_warning(review.id, revision_id, selection, "Invalid bank selection logic")
    end
  end

  defp create_warning(review_id, revision_id, selection, problem) do
    Warnings.create_warning(%{
      review_id: review_id,
      revision_id: revision_id,
      subtype: problem,
      content: selection
    })

    :ok
  end
end
