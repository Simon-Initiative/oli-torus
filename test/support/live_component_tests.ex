defmodule LiveComponentTests do
  @moduledoc """
  Conveniences for testing a LiveComponent in isolation.
  For more info visit https://elixirforum.com/t/liveview-isolated-component-tests/54893/6
  """

  defmodule Driver do
    @moduledoc """
    A LiveView for driving a LiveComponent under test.
    """
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <.live_component :if={@lc_module} module={@lc_module} {@lc_attrs} />
      """
    end

    def handle_call({:run, func}, _, socket) when is_function(func, 1) do
      func.(socket)
    end

    def mount(_, _, socket) do
      {:ok, assign(socket, lc_module: nil, lc_attrs: %{})}
    end

    ## Test Helpers

    def run(lv, func) do
      GenServer.call(lv.pid, {:run, func})
    end
  end

  ## Test helpers
  require Phoenix.LiveViewTest

  @doc """
  Spawns a Driver process to mount a LiveComponent in isolation as the sole rendered element.
  ## Examples
  Starting a LiveComponent under test:
      {:ok, lcd, html} = LiveComponentTest.live_component_isolated(conn, MyComponent)
  Starting a LiveComponent under test with attributes:
      {:ok, lcd, html} = LiveComponentTest.live_component_isolated(conn, MyComponent, foo: :bar)
  """
  defmacro live_component_isolated(conn, module, attrs \\ []) do
    quote bind_quoted: binding() do
      # Starts the Driver LiveView. It will render empty until we give it a `@module`.
      {:ok, lcd, _html} = Phoenix.LiveViewTest.live_isolated(conn, Driver)

      # <.live_component> requires an :id, so we set one if it's not already included.
      attrs = attrs |> Map.new() |> Map.put_new(:id, module)

      # Runs the given function _in the LiveView process_.
      Driver.run(lcd, fn socket ->
        {:reply, :ok, Phoenix.Component.assign(socket, lc_module: module, lc_attrs: attrs)}
      end)

      {:ok, lcd, Phoenix.LiveViewTest.render(lcd)}
    end
  end

  @doc """
  Intercepts messages on the LiveComponentTest LiveView.
  Use this function to intercept messages sent by the LiveComponent to the LiveView.
  ## Examples
      {:ok, lcd, _html} = LiveComponentTest.live_component_isolated(conn, MyLiveComponent)
      test_pid = self()
      live_component_test_intercept(lv, fn
          :message_to_intercept, socket ->
            send(test_pid, :intercepted)
            {:halt, socket}
          _other, socket ->
            {:cont, socket}
      end)
      assert_received :intercepted
  """
  def live_component_intercept(lv, func) when is_function(func) do
    Driver.run(lv, fn socket ->
      name = :"lcd_intercept_#{System.unique_integer([:positive, :monotonic])}"
      ref = {:intercept, lv, name, :handle_info}
      {:reply, ref, Phoenix.LiveView.attach_hook(socket, name, :handle_info, func)}
    end)
  end

  @doc """
  Intercepts events on the LiveComponentTest LiveView.
  Use this function to intercept events sent by the LiveComponent to the LiveView (when phx-target={@myself} is NOT defined).
  ## Examples
      {:ok, lcd, _html} = LiveComponentTest.live_component_isolated(conn, MyLiveComponent)
      test_pid = self()
      live_component_event_intercept(lv, fn
          "some_event_name" =  event, %{"some" => "example_params"} = params, socket ->
            send(test_pid, {:handle_event_intercepted, event, params})
            {:halt, socket}
          _other, _params, socket ->
            {:cont, socket}
      end)
      assert_received {:handle_event_intercepted, "some_event_name", %{"some" => "example_params"}}
  """
  def live_component_event_intercept(lv, func) when is_function(func) do
    Driver.run(lv, fn socket ->
      name = :"lv_event_intercept_#{System.unique_integer([:positive, :monotonic])}"
      ref = {:event_intercept, lv, name, :handle_event}
      {:reply, ref, Phoenix.LiveView.attach_hook(socket, name, :handle_event, func)}
    end)
  end

  @doc """
  Removes an intercept from the LiveComponentTest LiveView.
  ## Examples
      ref = LiveComponentTest.intercept(lv, fn msg, socket -> {:halt, socket} end)
      :ok = LiveComponentTest.remove_intercept(ref)
  """
  def live_component_remove_intercept({:intercept, lv, name, stage}) do
    Driver.run(lv, fn socket ->
      {:reply, :ok, Phoenix.LiveView.detach_hook(socket, name, stage)}
    end)
  end
end
