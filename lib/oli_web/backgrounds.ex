defmodule OliWeb.Backgrounds do
  @moduledoc """
  A collection of backgrounds used in the OliWeb application.
  """

  use Phoenix.Component

  def student_sign_in(assigns) do
    ~H"""
    <svg
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      class="h-[calc(100vh-112px)] w-full"
    >
      <g clip-path="url(#clip0_539_3635)">
        <rect class="h-[calc(100vh-112px)] w-full" fill="#1F1F1F" />
        <g filter="url(#filter0_f_539_3635)">
          <ellipse
            cx="1217.08"
            cy="662.134"
            rx="741.431"
            ry="793"
            fill={student_signin_background_color()}
          />
        </g>
        <g filter="url(#filter1_f_539_3635)">
          <ellipse cx="572.513" cy="936.433" rx="572.513" ry="611.433" fill="#0062F2" />
        </g>
        <g style="mix-blend-mode:color-burn" opacity="0.5">
          <rect class="h-[calc(100vh-112px)] w-full" fill="url(#pattern0_539_3635)" />
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
          <rect class="h-[calc(100vh-112px)] w-full" fill="white" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  defp student_signin_background_color do
    Application.fetch_env!(:oli, :student_sign_in)[:background_color]
  end

  def author_sign_in(assigns) do
    ~H"""
    <svg
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      class="h-full w-full"
    >
      <g clip-path="url(#clip0_539_3630)">
        <rect class="h-full w-full" fill="#B333CC" />
        <g filter="url(#filter0_f_539_3630)">
          <ellipse cx="472.399" cy="1080.62" rx="394.917" ry="599.233" fill="#0062F2" />
        </g>
        <g filter="url(#filter1_f_539_3630)">
          <ellipse cx="759.396" cy="665.883" rx="335.62" ry="509.132" fill="#B333CC" />
        </g>
        <g style="mix-blend-mode:color-burn" opacity="0.25">
          <rect class="h-full w-full" fill="url(#pattern0_539_3630)" />
        </g>
        <rect x="-2.31445" width="1920" height="1415.45" fill="black" fill-opacity="0.24" />
      </g>
      <defs>
        <filter
          id="filter0_f_539_3630"
          x="-431.519"
          y="225.384"
          width="1807.83"
          height="2216.47"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_539_3630" />
        </filter>
        <filter
          id="filter1_f_539_3630"
          x="-85.2246"
          y="-352.249"
          width="1689.24"
          height="2036.26"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_539_3630" />
        </filter>
        <pattern
          id="pattern0_539_3630"
          patternContentUnits="objectBoundingBox"
          width="0.197628"
          height="0.225056"
        >
          <use xlink:href="#image0_539_3630" transform="scale(9.88142e-05 0.000112528)" />
        </pattern>
        <clipPath id="clip0_539_3630">
          <rect class="h-full w-full" fill="white" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  def instructor_sign_in(assigns) do
    ~H"""
    <svg
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      class="h-[calc(100vh-112px)] w-full"
    >
      <g clip-path="url(#clip0_539_3635)">
        <rect class="h-[calc(100vh-112px)] w-full" fill="#1F1F1F" />
        <g filter="url(#filter0_f_539_3635)">
          <ellipse cx="1217.08" cy="662.134" rx="741.431" ry="793" fill="#0CAF61" />
        </g>
        <g filter="url(#filter1_f_539_3635)">
          <ellipse cx="572.513" cy="936.433" rx="572.513" ry="611.433" fill="#0062F2" />
        </g>
        <g style="mix-blend-mode:color-burn" opacity="0.5">
          <rect class="h-[calc(100vh-112px)] w-full" fill="url(#pattern0_539_3635)" />
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
          <rect class="h-[calc(100vh-112px)] w-full" fill="white" />
        </clipPath>
      </defs>
    </svg>
    """
  end
end
