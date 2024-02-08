defmodule OliWeb.Components.Delivery.Student do
  use OliWeb, :html

  attr :raw_avg_score, :map

  def score_summary(assigns) do
    ~H"""
    <div :if={@raw_avg_score[:score]} role="score summary" class="flex items-center gap-[6px] ml-auto">
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">
        <path
          d="M3.88301 14.0007L4.96634 9.31732L1.33301 6.16732L6.13301 5.75065L7.99967 1.33398L9.86634 5.75065L14.6663 6.16732L11.033 9.31732L12.1163 14.0007L7.99967 11.5173L3.88301 14.0007Z"
          fill="#0CAF61"
        />
      </svg>
      <span class="text-[12px] leading-[16px] tracking-[0.02px] text-[#0CAF61] font-semibold whitespace-nowrap">
        <%= format_float(@raw_avg_score[:score]) %> / <%= format_float(@raw_avg_score[:out_of]) %>
      </span>
    </div>
    """
  end

  defp format_float(float) do
    float
    |> round()
    |> trunc()
  end
end
