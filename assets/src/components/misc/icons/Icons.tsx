import React from 'react';

interface IconProps {
  className?: string;
  width?: number;
  height?: number;
  stroke?: string;
}

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
