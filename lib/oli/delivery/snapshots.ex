defmodule Oli.Delivery.Snapshots do
  @doc """
  Function designed to be piped the result of a Repo transaction that is finalizing
  one or more part attempt records, and if that function was successful this will
  trigger the creation of the corresponding snapshot records. This is designed to be used
  like:

  ```
  Repo.transaction(fn _ ->
    # impl that evaluates and finalizes part attempts based on part inputs
  end)
  |> Snapshots.maybe_create_snapshot(part_inputs, section_slug)
  ```
  """

  def maybe_create_snapshot(result, part_inputs, section_slug) do
    case result do
      {:ok, _} ->
        Enum.map(part_inputs, fn %{attempt_guid: attempt_guid} -> attempt_guid end)
        |> queue_or_create_snapshot(section_slug)

      _ ->
        {:ok, nil}
    end

    result
  end

  @doc """
  If background async job execution is enabled, queue the creation of snapshot records for
  these exising part attempt record guids. If background job execution is disabled, just create
  the snapshot records.
  """
  def queue_or_create_snapshot(part_attempt_guids, section_slug) do
    case Application.fetch_env!(:oli, Oban) |> Keyword.get(:queues, []) do
      false ->
        Oli.Delivery.Snapshots.Worker.perform_now(part_attempt_guids, section_slug)

      _ ->
        %{part_attempt_guids: part_attempt_guids, section_slug: section_slug}
        |> Oli.Delivery.Snapshots.Worker.new()
        |> Oban.insert()
    end
  end
end
