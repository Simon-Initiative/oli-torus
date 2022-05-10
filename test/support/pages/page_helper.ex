defmodule PageHelper do
  @moduledoc """
  Helper functions for writing hound based integration tests to wait for things to happen.

  For many cases, the default hound timeout/retry functionality will work out for you. For places
  with a lot of client-side logic, waiting longer may be required.

  """
  use Hound.Helpers

  @max_wait_ms 30000
  @retry_time_ms 1000

  @doc """
  Waits for an element to be visible and interactable, then clicks it.
  Will wait up to @max_wait_ms, retrying every @retry_time_ms
  Same arguments as hound find_element

  """
  def wait_click(strategy, selector) do
    {:ok, _} = wait_for_visible(strategy, selector)
    {:ok, element} = wait_for_interactable(strategy, selector)
    click(element)
  end

  @doc """
  Waits for an element to be visible
  Will wait up to @max_wait_ms, retrying every @retry_time_ms
  Same arguments as hound find_element

  Returns `{:ok, element}` or `{:error, reason}`
  """

  def wait_for_visible(strategy, selector) do
    wait_for_visible(strategy, selector, 10)
  end

  defp wait_for_visible(_, _, last_wait) when last_wait > @max_wait_ms do
    {:error, "Element not visible"}
  end

  defp wait_for_visible(strategy, selector, last_wait) do
    element = find_element(strategy, selector)

    if element_displayed?(element) do
      {:ok, element}
    else
      # The element wasn't ready yet, lets wait a bit and try again.
      :timer.sleep(@retry_time_ms)
      wait_for_visible(strategy, selector, last_wait + @retry_time_ms)
    end
  end

  @doc """
  Waits for an element to be interactable
  Will wait up to @max_wait_ms, retrying every @retry_time_ms
  Same arguments as hound find_element

  Returns `{:ok, element}` or `{:error, reason}`
  """
  def wait_for_interactable(strategy, selector) do
    wait_for_interactable(strategy, selector, 0)
  end

  defp wait_for_interactable(_, _, last_wait) when last_wait > @max_wait_ms do
    {:error, "Element not interactable"}
  end

  defp wait_for_interactable(strategy, selector, last_wait) do
    element = find_element(strategy, selector)

    if element_displayed?(element) and element_enabled?(element) do
      {:ok, element}
    else
      # The element wasn't ready yet, lets wait a bit and try again.
      :timer.sleep(@retry_time_ms)
      wait_for_interactable(strategy, selector, last_wait + @retry_time_ms)
    end
  end
end
