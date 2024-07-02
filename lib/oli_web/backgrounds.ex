defmodule OliWeb.Backgrounds do
  @moduledoc """
  A collection of backgrounds used in the OliWeb application.
  """

  use Phoenix.Component

  attr :host, :string, default: "localhost"

  def student_sign_in(%{host: "stellarator"} = assigns) do
    ~H"""
    <svg
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      class="h-[calc(100vh-56px)] w-full"
    >
      <g clip-path="url(#clip0_539_3635)">
        <rect class="h-[calc(100vh-56px)] w-full" fill="#1F1F1F" />
        <g filter="url(#filter0_f_539_3635)">
          <ellipse cx="1217.08" cy="662.134" rx="741.431" ry="793" fill="#DB6C1E" />
        </g>
        <g filter="url(#filter1_f_539_3635)">
          <ellipse cx="572.513" cy="936.433" rx="572.513" ry="611.433" fill="#0062F2" />
        </g>
        <g style="mix-blend-mode:color-burn" opacity="0.5">
          <rect class="h-[calc(100vh-56px)] w-full" fill="url(#pattern0_539_3635)" />
        </g>
      </g>
      <defs>
        <filter
          id="filter0_f_539_3635"
          x="-33.3496"
          y="-639.866"
          width="2500.86"
          height="2604"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_539_3635" />
        </filter>
        <filter
          id="filter1_f_539_3635"
          x="-547"
          y="-222"
          width="2239.03"
          height="2316.87"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="273.5" result="effect1_foregroundBlur_539_3635" />
        </filter>
        <pattern
          id="pattern0_539_3635"
          patternContentUnits="objectBoundingBox"
          width="0.198413"
          height="0.320513"
        >
          <use xlink:href="#image0_539_3635" transform="scale(9.92064e-05 0.000160256)" />
        </pattern>
        <clipPath id="clip0_539_3635">
          <rect class="h-[calc(100vh-56px)] w-full" fill="white" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  def student_sign_in(%{host: "tokamak"} = assigns) do
    ~H"""
    <svg
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      class="h-[calc(100vh-56px)] w-full"
    >
      <g clip-path="url(#clip0_553_7404)">
        <rect class="h-[calc(100vh-56px)] w-full" fill="#1F1F1F" />
        <g filter="url(#filter0_f_553_7404)">
          <ellipse cx="1217.08" cy="662.133" rx="741.431" ry="793" fill="#54E5A4" />
        </g>
        <g filter="url(#filter1_f_553_7404)">
          <ellipse cx="572.513" cy="936.433" rx="572.513" ry="611.433" fill="#0062F2" />
        </g>
        <g style="mix-blend-mode:color-burn" opacity="0.5">
          <rect class="h-[calc(100vh-56px)] w-full" fill="url(#pattern0_553_7404)" />
        </g>
      </g>
      <defs>
        <filter
          id="filter0_f_553_7404"
          x="-33.3496"
          y="-639.867"
          width="2500.86"
          height="2604"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_553_7404" />
        </filter>
        <filter
          id="filter1_f_553_7404"
          x="-547"
          y="-222"
          width="2239.03"
          height="2316.87"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="273.5" result="effect1_foregroundBlur_553_7404" />
        </filter>
        <pattern
          id="pattern0_553_7404"
          patternContentUnits="objectBoundingBox"
          width="0.198413"
          height="0.320513"
        >
          <use xlink:href="#image0_553_7404" transform="scale(9.92064e-05 0.000160256)" />
        </pattern>
        <clipPath id="clip0_553_7404">
          <rect class="h-[calc(100vh-56px)] w-full" fill="white" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  def student_sign_in(%{host: _} = assigns) do
    ~H"""
    <svg
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      class="h-[calc(100vh-56px)] w-full"
    >
      <g clip-path="url(#clip0_531_7671)">
        <rect class="h-[calc(100vh-56px)] w-full" fill="#1F1F1F" />
        <g filter="url(#filter0_f_531_7671)">
          <ellipse cx="1217.08" cy="662.133" rx="741.431" ry="793" fill="#FF82E4" />
        </g>
        <g filter="url(#filter1_f_531_7671)">
          <ellipse cx="572.513" cy="936.433" rx="572.513" ry="611.433" fill="#0062F2" />
        </g>
        <g style="mix-blend-mode:color-burn" opacity="0.5">
          <rect class="h-[calc(100vh-56px)] w-full" fill="url(#pattern0_531_7671)" />
        </g>
      </g>
      <defs>
        <filter
          id="filter0_f_531_7671"
          x="-33.3496"
          y="-639.867"
          width="2500.86"
          height="2604"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_531_7671" />
        </filter>
        <filter
          id="filter1_f_531_7671"
          x="-547"
          y="-222"
          width="2239.03"
          height="2316.87"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="273.5" result="effect1_foregroundBlur_531_7671" />
        </filter>
        <pattern
          id="pattern0_531_7671"
          patternContentUnits="objectBoundingBox"
          width="0.198413"
          height="0.320513"
        >
          <use xlink:href="#image0_531_7671" transform="scale(9.92064e-05 0.000160256)" />
        </pattern>
        <clipPath id="clip0_531_7671">
          <rect class="h-[calc(100vh-56px)] w-full" fill="white" />
        </clipPath>
      </defs>
    </svg>
    """
  end
end
