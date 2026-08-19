import React from 'react';

interface IconProps {
  className?: string;
  width?: number;
  height?: number;
  stroke?: string;
}

export const LearningObjectivesIcon: React.FC<IconProps> = ({
  className = '',
  width = 24,
  height = 24,
}) => (
  <svg
    className={className}
    width={width}
    height={height}
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    aria-hidden="true"
    focusable="false"
  >
    <path
      d="M21.2889 2.38012C21.4036 2.37652 21.5275 2.36592 21.6428 2.3584C21.6134 2.67586 21.6315 3.06431 21.6299 3.38648C21.624 4.59009 21.7105 5.53875 21.4162 6.71707C21.0398 8.22415 20.5116 9.58523 19.3168 10.6451C18.4907 11.3779 17.5598 11.8446 16.4619 11.9862C16.2738 12.0087 15.2978 12.0398 15.1874 11.9468C15.0782 11.6186 15.558 10.8106 15.7066 10.488C15.77 10.3503 15.8869 10.0619 15.9651 9.94896C16.2389 9.55418 16.5212 9.16838 16.7825 8.76373C17.1394 8.26685 17.6479 7.86513 17.9727 7.33973C18.0752 7.20616 18.0801 7.10198 18.1015 6.94352C18.1517 6.57037 17.6646 6.24253 17.3184 6.24337C16.6609 6.24499 16.4354 6.98309 16.0104 7.33448C15.931 7.40011 15.81 7.62764 15.734 7.71197C15.5023 8.0224 15.2652 8.32439 15.0674 8.6573C14.7556 9.12408 14.484 9.52741 14.2258 10.0297C14.1072 10.238 14.041 10.4947 13.9397 10.7074C13.531 11.5652 13.3 12.3807 13.0999 13.3017C12.9442 14.0182 12.7799 14.4228 12.8118 15.1916C12.3966 15.188 11.5823 15.1695 11.1951 15.2064C11.202 14.8519 11.1938 14.5641 11.1514 14.212C11.1008 13.791 10.9744 13.4768 10.8476 13.0779C10.7872 12.8879 10.7665 12.6424 10.6966 12.4605C10.3946 11.6745 9.86137 10.8981 9.32669 10.2473C9.17151 10.0659 8.97597 9.91746 8.80935 9.74899C8.23122 9.16441 7.61078 8.63759 6.98181 8.10973C6.79865 7.956 6.63534 7.78111 6.44385 7.62759C6.06545 7.32422 5.55655 7.33884 5.26305 7.75022C5.1648 7.89213 5.09226 8.09824 5.12242 8.27932C5.30104 8.9332 6.26106 9.46509 6.70694 9.99232C7.15159 10.5181 7.5535 11.028 7.97547 11.5725C7.97193 11.7055 7.97601 11.8285 7.98018 11.961C7.78553 11.9793 7.59041 11.9919 7.39504 11.999C6.07567 12.0453 5.00388 11.5986 4.09654 10.6533C3.66991 10.2087 3.28905 9.64868 3.00564 9.09926C2.92328 8.93958 2.89047 8.7154 2.81999 8.54843C2.76482 8.403 2.66746 8.2065 2.6256 8.06813C2.58941 7.9485 2.59202 7.66643 2.55604 7.52538C2.50195 7.31332 2.41061 7.14663 2.39652 6.92602C2.33365 5.94202 2.39268 4.93486 2.35938 3.9498C2.63882 3.996 3.25898 3.9813 3.56636 3.98109L5.09987 3.98079C5.63158 3.9843 6.03555 3.97153 6.53983 4.14598C6.68641 4.1967 6.96977 4.23026 7.1354 4.27214C8.67386 4.67916 9.65409 5.66224 10.1785 7.14209C10.4435 7.89 10.3782 8.19073 10.4586 8.90393C10.4766 9.06413 11.2425 10.0172 11.3859 10.2582C11.5434 10.5228 11.7186 10.9199 11.8704 11.1929C12.1383 10.7975 12.4605 10.3364 12.2685 9.85437C12.0674 9.34962 12.0028 9.02257 12.003 8.47854C12.0033 7.95509 11.9736 7.39798 12.0685 6.87724C12.1134 6.63045 12.2158 6.37997 12.2712 6.13418C12.374 5.56275 12.6306 5.18292 12.9749 4.73154C13.1006 4.5667 13.2643 4.2904 13.4121 4.14769C14.1502 3.43516 15.061 2.99255 16.0395 2.71003C16.2043 2.66025 16.3932 2.64663 16.5571 2.59845C17.3616 2.36196 18.1246 2.38659 18.9579 2.38676C19.7349 2.39177 20.512 2.38957 21.2889 2.38012Z"
      fill="currentColor"
    />
    <path
      d="M11.4455 16.7912C12.3389 16.738 13.05 16.7796 13.8784 17.161C14.1406 17.2818 14.4356 17.4976 14.7146 17.5564C15.0055 17.6177 15.3828 17.5548 15.6828 17.5848C15.8971 17.6089 16.35 17.7524 16.5684 17.8188C16.8828 17.9144 17.2977 18.2969 17.5975 18.4174C17.7745 18.4593 18.0638 18.4415 18.2428 18.4261C20.1451 18.2626 21.531 19.8005 21.6444 21.6347C21.3582 21.6024 20.8133 21.6144 20.5124 21.6141L18.5131 21.6137L12.0346 21.614L5.49603 21.6137L3.51654 21.6133C3.19536 21.6133 2.67106 21.5981 2.37247 21.637C2.31121 19.477 4.30944 17.4903 6.47722 17.5734C6.87683 17.5347 7.54948 17.6929 7.9028 17.8755C8.8422 18.3612 8.56308 18.1406 9.23201 17.6322C9.73337 17.2511 10.8033 16.8283 11.4455 16.7912Z"
      fill="currentColor"
    />
  </svg>
);

export const SearchIcon: React.FC<IconProps> = ({ className = '', width = 21, height = 20 }) => (
  <svg
    className={className}
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 21 20"
    width={width}
    height={height}
  >
    <path
      d="M19.658 19L13.7313 13M1.87793 8C1.87793 8.91925 2.05678 9.82951 2.40426 10.6788C2.75175 11.5281 3.26106 12.2997 3.90313 12.9497C4.5452 13.5998 5.30744 14.1154 6.14634 14.4672C6.98524 14.8189 7.88437 15 8.79239 15C9.70041 15 10.5995 14.8189 11.4384 14.4672C12.2773 14.1154 13.0396 13.5998 13.6817 12.9497C14.3237 12.2997 14.833 11.5281 15.1805 10.6788C15.528 9.82951 15.7069 8.91925 15.7069 8C15.7069 7.08075 15.528 6.1705 15.1805 5.32122C14.833 4.47194 14.3237 3.70026 13.6817 3.05025C13.0396 2.40024 12.2773 1.88463 11.4384 1.53284C10.5995 1.18106 9.70041 1 8.79239 1C7.88437 1 6.98524 1.18106 6.14634 1.53284C5.30744 1.88463 4.5452 2.40024 3.90313 3.05025C3.26106 3.70026 2.75175 4.47194 2.40426 5.32122C2.05678 6.1705 1.87793 7.08075 1.87793 8Z"
      className="stroke-current"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const ExpandAllIcon: React.FC<IconProps> = ({ className = '', width = 9, height = 19 }) => (
  <svg
    className={className}
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 9 19"
    width={width}
    height={height}
    fill="none"
  >
    <path
      d="M1 4.49996L4.49996 1L7.99992 4.49996"
      className="stroke-current"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M8 14L4.50004 17.5L1.00008 14"
      className="stroke-current"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const CollapseAllIcon: React.FC<IconProps> = ({
  className = '',
  width = 9,
  height = 19,
}) => (
  <svg
    className={className}
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 9 19"
    width={width}
    height={height}
    fill="none"
  >
    <path
      d="M8 1.00004L4.50004 4.5L1.00008 1.00004"
      className="stroke-current"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M1 17.6411L4.49996 14.1411L7.99991 17.6411"
      className="stroke-current"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const ClearIcon: React.FC<IconProps> = ({ className = '', width = 16, height = 18 }) => (
  <svg
    className={className}
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 16 18"
    width={width}
    height={height}
    fill="none"
  >
    <path
      d="M1.3335 4.83333H14.6668M6.3335 8.16667V13.1667M9.66683 8.16667V13.1667M2.16683 4.83333L3.00016 14.8333C3.00016 15.2754 3.17576 15.6993 3.48832 16.0118C3.80088 16.3244 4.2248 16.5 4.66683 16.5H11.3335C11.7755 16.5 12.1994 16.3244 12.512 16.0118C12.8246 15.6993 13.0002 15.2754 13.0002 14.8333L13.8335 4.83333M5.50016 4.83333V2.33333C5.50016 2.11232 5.58796 1.90036 5.74424 1.74408C5.90052 1.5878 6.11248 1.5 6.3335 1.5H9.66683C9.88784 1.5 10.0998 1.5878 10.2561 1.74408C10.4124 1.90036 10.5002 2.11232 10.5002 2.33333V4.83333"
      className="stroke-current"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const FilterIcon: React.FC<IconProps> = ({ className = '', width = 20, height = 22 }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    className={className}
    width={width}
    height={height}
    viewBox="0 0 24 24"
    fill="none"
  >
    <path
      d="M4 4H20V6.172C19.9999 6.70239 19.7891 7.21101 19.414 7.586L15 12V19L9 21V12.5L4.52 7.572C4.18545 7.20393 4.00005 6.7244 4 6.227V4Z"
      className="stroke-current"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const EyeIcon: React.FC<IconProps> = ({ className = '', width = 20, height = 22 }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    className={className}
    width={width}
    height={height}
    viewBox="0 0 24 24"
    fill="none"
  >
    <path
      d="M10 12C10 12.5304 10.2107 13.0391 10.5858 13.4142C10.9609 13.7893 11.4696 14 12 14C12.5304 14 13.0391 13.7893 13.4142 13.4142C13.7893 13.0391 14 12.5304 14 12C14 11.4696 13.7893 10.9609 13.4142 10.5858C13.0391 10.2107 12.5304 10 12 10C11.4696 10 10.9609 10.2107 10.5858 10.5858C10.2107 10.9609 10 11.4696 10 12Z"
      className="stroke-current"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M21 12C18.6 16 15.6 18 12 18C8.4 18 5.4 16 3 12C5.4 8 8.4 6 12 6C15.6 6 18.6 8 21 12Z"
      className="stroke-current"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const CloseIcon: React.FC<IconProps> = ({
  className = '',
  width = 17,
  height = 18,
  stroke = '#757682',
}) => (
  <svg
    className={className}
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 17 18"
    width={width}
    height={height}
    fill="none"
  >
    <path
      d="M1 1.57324L15.5571 16.1304M15.5571 1.57324L1 16.1304"
      stroke={stroke}
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const ChevronDown: React.FC<IconProps> = ({ className = '', width = 16, height = 16 }) => (
  <svg
    width={width}
    height={height}
    viewBox="0 0 24 24"
    xmlns="http://www.w3.org/2000/svg"
    className={className}
    fill="currentColor"
  >
    <path d="M6.70711 8.29289C6.31658 7.90237 5.68342 7.90237 5.29289 8.29289C4.90237 8.68342 4.90237 9.31658 5.29289 9.70711L11.2929 15.7071C11.6834 16.0976 12.3166 16.0976 12.7071 15.7071L18.7071 9.70711C19.0976 9.31658 19.0976 8.68342 18.7071 8.29289C18.3166 7.90237 17.6834 7.90237 17.2929 8.29289L12 13.5858L6.70711 8.29289Z" />
  </svg>
);

export const ArrowRight: React.FC<IconProps> = ({ className = '', width = 16, height = 16 }) => (
  <svg
    className={className}
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 16 16"
    width={width}
    height={height}
    fill="none"
  >
    <path
      d="M3.33301 8H12.6663M8.66634 4L12.6663 8L8.66634 12"
      className="stroke-current"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);
