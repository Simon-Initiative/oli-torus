defmodule OliWeb.Admin.UploadPipelineView do
  use OliWeb, :live_view

  alias Phoenix.PubSub
  alias OliWeb.Common.Breadcrumb

  # Controls the number of stats to keep in the window, effectively making
  # ours stats a rolling window of the last @window_size stats.
  @window_size 500

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(_, _, socket) do
    PubSub.subscribe(Oli.PubSub, "xapi_upload_pipeline_stats")

    {:ok, %{rows: [[count]]}} = Oli.Repo.query("SELECT Count(*) FROM pending_uploads")

    # setup a timer to query the pending_uploads every 10 seconds
    Process.send_after(self(), :query_pending_uploads, 10_000)

    {:ok,
     assign(socket,
       title: "XAPI Upload Pipeline",
       breadcrumb: breadcrumb(),
       raw_stats: [],
       throughput_per_second: nil,
       batch_size_stats: nil,
       upload_time_stats: nil,
       messages: [],
       pending_count: count
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="w-full bg-stone-950 dark:text-white">
      <div class="w-full p-8 justify-start items-start gap-6 inline-flex">
        <.stats title="Batch Size" stats={@batch_size_stats} suffix="" />
        <.stats title="S3 Upload Time" stats={@upload_time_stats} suffix="ms" />
      </div>
      <div class="w-full p-8 justify-start items-start gap-6 inline-flex">
        <.stats title="Throughput" stats={@throughput_per_second} />
        <.pending pending_count={@pending_count} />
      </div>
    </div>
    """
  end

  attr(:stats, :any, required: true)
  attr(:title, :string, required: true)
  attr(:suffix, :string, default: "")

  defp stats(assigns) do
    ~H"""
    <div class="w-1/4 flex-col justify-start items-start gap-6 inline-flex">
      <div class="w-full p-6 bg-zinc-900 bg-opacity-20 dark:bg-opacity-100 rounded-2xl justify-start items-start gap-32 inline-flex">
        <div class="flex-col justify-start items-start gap-5 inline-flex grow">
          <div class="justify-start items-start gap-2.5 inline-flex">
            <div class="text-2xl font-bold leading-loose tracking-tight">
              <%= @title %>
            </div>
          </div>
          <div class="flex-col justify-start items-start flex">
            <%= render_stats(assigns) %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr(:pending_count, :any, required: true)

  defp pending(assigns) do
    ~H"""
    <div class="w-1/4 h-48 flex-col justify-start items-start gap-6 inline-flex">
      <div class="w-full h-96 p-6 bg-zinc-900 bg-opacity-20 dark:bg-opacity-100 rounded-2xl justify-start items-start gap-32 inline-flex">
        <div class="flex-col justify-start items-start gap-5 inline-flex grow">
          <div class="justify-start items-start gap-2.5 inline-flex">
            <div class="text-2xl font-bold leading-loose tracking-tight">
              Pending Uploads
            </div>
          </div>
          <div class="flex-col justify-start items-start flex">
            <%= @pending_count %> total bundles
          </div>
          <%= if @pending_count > 0 do %>
            <div class="flex-col justify-start items-start flex">
              <.button class="btn btn-primary" phx-click="queue">Re-enqueue</.button>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format(v, s) when is_float(v), do: "#{Float.round(v, 3)}#{s}"
  defp format(v, s), do: "#{v}#{s}"

  defp render_stats(%{stats: %{mean: _}} = assigns) do
    ~H"""
    <div>
      <div class="text-sm text-gray-400">Mean</div>
      <div class="text-2xl font-bold text-gray-100"><%= format(@stats.mean, @suffix) %></div>
      <div class="text-sm text-gray-400">Min</div>
      <div class="text-2xl font-bold text-gray-100"><%= format(@stats.min, @suffix) %></div>
      <div class="text-sm text-gray-400">Max</div>
      <div class="text-2xl font-bold text-gray-100"><%= format(@stats.max, @suffix) %></div>
      <div class="text-sm text-gray-400">StdDev</div>
      <div class="text-2xl font-bold text-gray-100"><%= format(@stats.std_dev, @suffix) %></div>
    </div>
    """
  end

  defp render_stats(%{stats: nil} = assigns) do
    ~H"""
    <div></div>
    """
  end

  defp render_stats(assigns) do
    ~H"""
    <div>
      <div class="text-2xl font-bold text-gray-100"><%= format(@stats, " statements/s") %></div>
    </div>
    """
  end

  def handle_event("queue", _params, socket) do
    producer =
      Oli.Analytics.XAPI.UploadPipeline
      |> Broadway.producer_names()
      |> Enum.random()

    GenStage.cast(producer, {:enqueue_from_storage})

    {:noreply, socket}
  end

  def handle_info(:query_pending_uploads, socket) do
    {:ok, %{rows: [[count]]}} = Oli.Repo.query("SELECT Count(*) FROM pending_uploads")
    Process.send_after(self(), :query_pending_uploads, 10_000)
    {:noreply, assign(socket, pending_count: count)}
  end

  def handle_info({:stats, {batch_size, upload_time}}, socket) do
    raw_stats =
      [{batch_size, upload_time, System.monotonic_time()} | socket.assigns.raw_stats]
      |> Enum.take(@window_size)

    throughput_per_second = throughput_per_second(raw_stats)

    count = Enum.count(raw_stats)

    {batch_sizes, uploads, _} =
      Enum.reduce(raw_stats, {[], [], nil}, fn {size, upload, _}, {batch_sizes, uploads, _} ->
        {[size | batch_sizes], [upload | uploads], []}
      end)

    batch_sizes = Enum.reverse(batch_sizes)
    uploads = Enum.reverse(uploads)

    batch_size_stats = calculate_distribution_stats(batch_sizes, count)
    upload_time_stats = calculate_distribution_stats(uploads, count)

    {:noreply,
     assign(socket,
       raw_stats: raw_stats,
       batch_size_stats: batch_size_stats,
       upload_time_stats: upload_time_stats,
       throughput_per_second: throughput_per_second
     )}
  end

  defp throughput_per_second(raw_stats) do
    stats =
      Enum.reduce(raw_stats, %{count: 0, last_time: nil}, fn {size, _, time},
                                                             %{
                                                               count: count,
                                                               last_time: _last_time
                                                             } ->
        %{count: count + size, last_time: time}
      end)

    diff = ((raw_stats |> hd() |> elem(2)) - stats.last_time) / 1000 / 1000 / 1000

    if diff > 0 do
      stats.count / diff
    else
      0.0
    end
  end

  defp calculate_distribution_stats(raw_stats, count) do
    # Calculate the mean
    mean = Enum.reduce(raw_stats, 0, fn v, acc -> acc + v end) / count

    # Calculate the standard deviation
    variance = Enum.reduce(raw_stats, 0, fn v, acc -> acc + (v - mean) * (v - mean) end) / count
    std_dev = :math.sqrt(variance)

    min = Enum.min(raw_stats)
    max = Enum.max(raw_stats)

    %{mean: mean, std_dev: std_dev, min: min, max: max}
  end

  defp breadcrumb(),
    do:
      OliWeb.Admin.AdminView.breadcrumb() ++
        [Breadcrumb.new(%{full_title: "XAPI Upload Pipeline", link: ~p"/admin"})]
end
