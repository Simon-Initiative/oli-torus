defmodule OliWeb.Experiments.ExperimentsView do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, :live}

  import OliWeb.Components.Common

  def mount(_params, _session, socket) do
    {:ok, assign(socket, title: "Experiments")}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-y-6 ml-8 mt-4">
      <h3>A/B Testing with UpGrade</h3>
      <p>
        To support A/B testing, Torus integrates with the A/B testing platform,
        <a
          class="underline text-inherit decoration-grey-500/30"
          href="https://upgrade.oli.cmu.edu/login"
        >
          UpGrade
        </a>
      </p>
      <.input
        type="checkbox"
        class="form-check-input"
        name="experiments"
        value={nil}
        label="Enable A/B testing with UpGrade"
      />
    </div>
    """
  end
end
