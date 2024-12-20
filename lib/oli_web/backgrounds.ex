defmodule OliWeb.Backgrounds do
  @moduledoc """
  A collection of backgrounds used in the OliWeb application.
  """

  use Phoenix.Component

  def student_sign_in(assigns) do
    ~H"""
    <svg
      class="w-full h-full"
      preserveAspectRatio="none"
      viewBox="0 0 1512 936"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
    >
      <g clip-path="url(#clip0_531_7671)">
        <rect width="1512" height="936" fill="#1F1F1F" />
        <g filter="url(#filter0_f_531_7671)">
          <ellipse
            cx="1217.08"
            cy="662.133"
            rx="741.431"
            ry="793"
            fill={student_signin_background_color()}
          />
        </g>
        <g filter="url(#filter1_f_531_7671)">
          <ellipse cx="572.513" cy="936.433" rx="572.513" ry="611.433" fill="#0062F2" />
        </g>
        <g style="mix-blend-mode:color-burn" opacity="0.5">
          <rect width="1512" height="936" fill="url(#pattern0_531_7671)" />
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
          <rect width="1512" height="936" fill="white" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  def instructor_dashboard_header(assigns) do
    ~H"""
    <svg
      width="120%"
      height="291"
      viewBox="0 0 100% 291"
      preserveAspectRatio="none"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
    >
      <g clip-path="url(#clip0_494_8778)">
        <rect width="100%" height="291" class="fill-[#87E1B6] dark:fill-[#0CAF61]" />
        <g filter="url(#filter0_f_494_8778)">
          <ellipse
            cx="408.292"
            cy="291.135"
            rx="341.325"
            ry="130.815"
            class="fill-[#9AC3FF] dark:fill-[#0062F2]"
          />
        </g>
        <g filter="url(#filter1_f_494_8778)">
          <ellipse
            cx="656.342"
            cy="145.366"
            rx="290.075"
            ry="111.146"
            class="fill-[#87E1B6] dark:fill-[#0CAF61]"
          />
        </g>
        <g style="mix-blend-mode:color-burn" opacity="0.25">
          <rect width="100%" height="291" fill="url(#pattern0_494_8778)" />
        </g>
        <rect
          width="100%"
          height="309"
          class="fill-white dark:fill-black opacity-[0.15] dark:opacity-[0.3]"
        />
      </g>
      <defs>
        <filter
          id="filter0_f_494_8778"
          x="-442.033"
          y="-348.681"
          width="1700.65"
          height="1279.63"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_494_8778" />
        </filter>
        <filter
          id="filter1_f_494_8778"
          x="-142.733"
          y="-474.78"
          width="1598.15"
          height="1240.29"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_494_8778" />
        </filter>
        <pattern
          id="pattern0_494_8778"
          patternContentUnits="objectBoundingBox"
          width="0.228659"
          height="1.03093"
        >
          <use xlink:href="#image0_494_8778" transform="scale(0.000114329 0.000515464)" />
        </pattern>
        <clipPath id="clip0_494_8778">
          <rect width="100%" height="291" fill="white" />
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
      class="w-full h-full"
      preserveAspectRatio="none"
      viewBox="0 0 1518 1333"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
    >
      <g clip-path="url(#clip0_539_3630)">
        <rect width="1518" height="1333" fill="#B333CC" />
        <g filter="url(#filter0_f_539_3630)">
          <ellipse cx="472.399" cy="1333.62" rx="394.917" ry="599.233" fill="#0062F2" />
        </g>
        <g filter="url(#filter1_f_539_3630)">
          <ellipse cx="759.396" cy="665.883" rx="335.62" ry="509.132" fill="#B333CC" />
        </g>
        <g style="mix-blend-mode:color-burn" opacity="0.25">
          <rect width="1518" height="1333" fill="url(#pattern0_539_3630)" />
        </g>
        <rect x="-2" width="1520" height="1415" fill="black" fill-opacity="0.24" />
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
          <rect width="1518" height="1333" fill="white" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  def instructor_sign_in(assigns) do
    ~H"""
    <svg
      class="w-full h-full"
      preserveAspectRatio="none"
      viewBox="0 0 1528 1264"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
    >
      <g clip-path="url(#clip0_539_3625)">
        <rect width="1528" height="1264" fill="#0CAF61" />
        <g filter="url(#filter0_f_539_3625)">
          <ellipse cx="475.51" cy="1264.58" rx="397.519" ry="568.215" fill="#0062F2" />
        </g>
        <g filter="url(#filter1_f_539_3625)">
          <ellipse cx="764.398" cy="631.415" rx="337.831" ry="482.778" fill="#0CAF61" />
        </g>
        <g style="mix-blend-mode:color-burn" opacity="0.25">
          <rect width="1528" height="1264" fill="url(#pattern0_539_3625)" />
        </g>
        <rect width="1528" height="1355" fill="black" fill-opacity="0.3" />
      </g>
      <defs>
        <filter
          id="filter0_f_539_3625"
          x="-431.009"
          y="187.37"
          width="1813.04"
          height="2154.43"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_539_3625" />
        </filter>
        <filter
          id="filter1_f_539_3625"
          x="-82.4336"
          y="-360.363"
          width="1693.66"
          height="1983.56"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_539_3625" />
        </filter>
        <pattern
          id="pattern0_539_3625"
          patternContentUnits="objectBoundingBox"
          width="0.196335"
          height="0.237342"
        >
          <use xlink:href="#image0_539_3625" transform="scale(9.81675e-05 0.000118671)" />
        </pattern>
        <clipPath id="clip0_539_3625">
          <rect width="1528" height="1264" fill="white" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  def course_author_header(assigns) do
    ~H"""
    <svg
      width="100%"
      height="291"
      viewBox="0 0 1310 291"
      preserveAspectRatio="none"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
    >
      <g clip-path="url(#clip0_554_23928)">
        <rect width="100%" height="291" class="fill-[#B333CC] opacity-40 dark:opacity-100" />
        <g filter="url(#filter0_f_554_23928)">
          <ellipse
            cx="408.292"
            cy="291.135"
            rx="341.325"
            ry="130.815"
            class="fill-[#0062F2] opacity-25 dark:opacity-100"
          />
        </g>
        <g filter="url(#filter1_f_554_23928)">
          <ellipse
            cx="656.343"
            cy="145.366"
            rx="290.075"
            ry="111.146"
            class="fill-[#B333CC] opacity-40 dark:opacity-100"
          />
        </g>
        <g style="mix-blend-mode:color-burn" opacity="0.25">
          <rect width="100%" height="291" fill="url(#pattern0_554_23928)" />
        </g>
      </g>
      <defs>
        <filter
          id="filter0_f_554_23928"
          x="-442.033"
          y="-348.681"
          width="1700.65"
          height="1279.63"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_554_23928" />
        </filter>
        <filter
          id="filter1_f_554_23928"
          x="-142.732"
          y="-474.78"
          width="1598.15"
          height="1240.29"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_554_23928" />
        </filter>
        <pattern
          id="pattern0_554_23928"
          patternContentUnits="objectBoundingBox"
          width="0.228659"
          height="1.03093"
        >
          <use xlink:href="#image0_554_23928" transform="scale(0.000114329 0.000515464)" />
        </pattern>
        <clipPath id="clip0_554_23928">
          <rect width="100%" height="291" fill="white" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  def student_workspace_sign_in(assigns) do
    ~H"""
    <svg
      class="w-full h-full"
      viewBox="0 0 1312 1040"
      preserveAspectRatio="none"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
    >
      <g clip-path="url(#clip0_542_4263)">
        <rect width="1796" height="1112" transform="translate(0 -28)" fill="#1F1F1F" />
        <g filter="url(#filter0_f_542_4263)">
          <ellipse cx="1445.69" cy="758.637" rx="880.695" ry="942.111" fill="#DB6C1E" />
        </g>
        <g filter="url(#filter1_f_542_4263)">
          <ellipse cx="680.048" cy="1084.51" rx="680.048" ry="726.404" fill="#0062F2" />
        </g>
        <g style="mix-blend-mode:color-burn" opacity="0.5">
          <rect y="-28" width="1796" height="1112" fill="url(#pattern0_542_4263)" />
        </g>
      </g>
      <defs>
        <filter
          id="filter0_f_542_4263"
          x="55.9917"
          y="-692.474"
          width="2779.39"
          height="2902.22"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_542_4263" />
        </filter>
        <filter
          id="filter1_f_542_4263"
          x="-547"
          y="-188.889"
          width="2454.1"
          height="2546.81"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="273.5" result="effect1_foregroundBlur_542_4263" />
        </filter>
        <pattern
          id="pattern0_542_4263"
          patternContentUnits="objectBoundingBox"
          width="0.167038"
          height="0.269784"
        >
          <use xlink:href="#image0_542_4263" transform="scale(8.35189e-05 0.000134892)" />
        </pattern>
        <clipPath id="clip0_542_4263">
          <rect width="1796" height="1112" fill="white" transform="translate(0 -28)" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  def instructor_workspace_sign_in(assigns) do
    ~H"""
    <svg
      class="w-full h-full"
      preserveAspectRatio="none"
      viewBox="0 0 1310 1010"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
    >
      <g clip-path="url(#clip0_542_4075)">
        <rect width="1528" height="1264" transform="translate(0 -18)" fill="#0CAF61" />
        <g filter="url(#filter0_f_542_4075)">
          <ellipse cx="475.51" cy="1246.58" rx="397.519" ry="568.215" fill="#0062F2" />
        </g>
        <g filter="url(#filter1_f_542_4075)">
          <ellipse cx="764.398" cy="613.415" rx="337.831" ry="482.778" fill="#0CAF61" />
        </g>
        <g style="mix-blend-mode:color-burn" opacity="0.25">
          <rect y="-18" width="1528" height="1264" fill="url(#pattern0_542_4075)" />
        </g>
        <rect y="-4.96924" width="1528" height="1342.19" fill="black" fill-opacity="0.3" />
      </g>
      <defs>
        <filter
          id="filter0_f_542_4075"
          x="-431.008"
          y="169.37"
          width="1813.04"
          height="2154.43"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_542_4075" />
        </filter>
        <filter
          id="filter1_f_542_4075"
          x="-82.4333"
          y="-378.363"
          width="1693.66"
          height="1983.56"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_542_4075" />
        </filter>
        <pattern
          id="pattern0_542_4075"
          patternContentUnits="objectBoundingBox"
          width="0.196335"
          height="0.237342"
        >
          <use xlink:href="#image0_542_4075" transform="scale(9.81675e-05 0.000118671)" />
        </pattern>
        <clipPath id="clip0_542_4075">
          <rect width="1528" height="1264" fill="white" transform="translate(0 -18)" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  def course_author_workspace_sign_in(assigns) do
    ~H"""
    <svg
      class="w-full h-full"
      preserveAspectRatio="none"
      viewBox="0 0 1322 1007"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <g clip-path="url(#clip0_26_6935)">
        <rect width="1322" height="1007" fill="#B333CC" />
        <g filter="url(#filter0_f_26_6935)">
          <ellipse cx="411.404" cy="1007.47" rx="343.927" ry="452.684" fill="#0062F2" />
        </g>
        <g filter="url(#filter1_f_26_6935)">
          <ellipse cx="661.344" cy="503.034" rx="292.286" ry="384.618" fill="#B333CC" />
        </g>
        <rect x="-2.01514" width="1322" height="1069.29" fill="black" fill-opacity="0.24" />
      </g>
      <defs>
        <filter
          id="filter0_f_26_6935"
          x="-441.523"
          y="45.7825"
          width="1705.85"
          height="1923.37"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_26_6935" />
        </filter>
        <filter
          id="filter1_f_26_6935"
          x="-139.941"
          y="-390.584"
          width="1602.57"
          height="1787.24"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feFlood flood-opacity="0" result="BackgroundImageFix" />
          <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
          <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_26_6935" />
        </filter>
        <clipPath id="clip0_26_6935">
          <rect width="1322" height="1007" fill="white" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  def enrollment_info(assigns) do
    ~H"""
    <div class="flex justify-end relative w-full h-[427px]">
      <img
        src="/images/enrollment_info.png"
        alt="A student looks at her computer to browse course topics."
      />
      <svg
        class="absolute top-0"
        height="427"
        viewBox="0 0 1510 427"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        xmlns:xlink="http://www.w3.org/1999/xlink"
      >
        <g clip-path="url(#clip0_494_5035)">
          <rect x="413" y="-27" width="1102" height="416" fill="url(#pattern0_494_5035)" />
          <g filter="url(#filter0_f_494_5035)">
            <ellipse cx="462.423" cy="424.194" rx="402.462" ry="188.356" fill="#0062F2" />
          </g>
          <g filter="url(#filter1_f_494_5035)">
            <ellipse cx="754.903" cy="214.306" rx="342.032" ry="160.035" fill="#0CAF61" />
          </g>
          <g style="mix-blend-mode:color-burn" opacity="0.25">
            <rect x="-19" y="5" width="1547" height="419" fill="url(#pattern1_494_5035)" />
          </g>
        </g>
        <rect x="-19" width="1570" height="427" fill="url(#paint0_linear_494_5035)" />
        <defs>
          <pattern id="pattern0_494_5035" patternContentUnits="objectBoundingBox" width="1" height="1">
            <use
              xlink:href="#image0_494_5035"
              transform="matrix(0.000244141 0 0 0.000626464 0.0284498 0.0178075)"
            />
          </pattern>
          <filter
            id="filter0_f_494_5035"
            x="-449.039"
            y="-273.162"
            width="1822.92"
            height="1394.71"
            filterUnits="userSpaceOnUse"
            color-interpolation-filters="sRGB"
          >
            <feFlood flood-opacity="0" result="BackgroundImageFix" />
            <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
            <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_494_5035" />
          </filter>
          <filter
            id="filter1_f_494_5035"
            x="-96.1289"
            y="-454.729"
            width="1702.06"
            height="1338.07"
            filterUnits="userSpaceOnUse"
            color-interpolation-filters="sRGB"
          >
            <feFlood flood-opacity="0" result="BackgroundImageFix" />
            <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
            <feGaussianBlur stdDeviation="254.5" result="effect1_foregroundBlur_494_5035" />
          </filter>
          <pattern
            id="pattern1_494_5035"
            patternContentUnits="objectBoundingBox"
            width="0.193924"
            height="0.71599"
          >
            <use xlink:href="#image1_494_5035" transform="scale(9.69619e-05 0.000357995)" />
          </pattern>
          <linearGradient
            id="paint0_linear_494_5035"
            x1="-19"
            y1="213.5"
            x2="1551"
            y2="213.5"
            gradientUnits="userSpaceOnUse"
          >
            <stop />
            <stop offset="1" stop-color="#737373" stop-opacity="0" />
          </linearGradient>
          <clipPath id="clip0_494_5035">
            <rect width="1570" height="427" fill="none" />
          </clipPath>
        </defs>
      </svg>
    </div>
    """
  end

  def student_invitation(assigns) do
    ~H"""
    <.student_sign_in />
    """
  end

  def instructor_invitation(assigns) do
    ~H"""
    <.instructor_sign_in />
    """
  end
end
