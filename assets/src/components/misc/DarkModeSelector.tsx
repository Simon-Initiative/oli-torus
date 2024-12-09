import React, { useState } from 'react';
import { ThreeStateToggle, ToggleOption } from 'components/common/ThreeStateToggle';
import { isDarkMode } from 'utils/browser';
import { classNames } from 'utils/classNames';

type Mode = 'auto' | 'light' | 'dark';

const isChecked = (checked: string, state: string) => checked === state;

export const getModeFromLocalStorage = () => {
  if (!('theme' in localStorage)) {
    return 'auto';
  }

  return localStorage.theme;
};

export interface DarkModeSelectorProps {}

export const DarkModeSelector = (_props: DarkModeSelectorProps) => {
  const [mode, setMode] = useState<Mode>(getModeFromLocalStorage());

  const onSelect = (mode: Mode) => () => {
    if (mode === 'auto') {
      if (isDarkMode()) {
        document.documentElement.classList.add('dark');
      } else {
        document.documentElement.classList.remove('dark');
      }
      localStorage.removeItem('theme');
    } else if (mode === 'dark') {
      document.documentElement.classList.add('dark');
      localStorage.setItem('theme', mode);
    } else {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('theme', mode);
    }

    setMode(mode);
  };

  return (
    <ThreeStateToggle>
      <ToggleOption id="auto" checked={isChecked(mode, 'auto')} onChange={onSelect('auto')}>
        <svg
          className={classNames(
            isChecked(mode, 'auto') && 'hidden',
            'dark:stroke-[#B8B4BF] stroke-black/70 hover:stroke-black hover:dark:stroke-white',
          )}
          width="20"
          height="20"
          viewBox="0 0 20 20"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M3 10C3 10.9193 3.18106 11.8295 3.53284 12.6788C3.88463 13.5281 4.40024 14.2997 5.05025 14.9497C5.70026 15.5998 6.47194 16.1154 7.32122 16.4672C8.1705 16.8189 9.08075 17 10 17C10.9193 17 11.8295 16.8189 12.6788 16.4672C13.5281 16.1154 14.2997 15.5998 14.9497 14.9497C15.5998 14.2997 16.1154 13.5281 16.4672 12.6788C16.8189 11.8295 17 10.9193 17 10C17 9.08075 16.8189 8.1705 16.4672 7.32122C16.1154 6.47194 15.5998 5.70026 14.9497 5.05025C14.2997 4.40024 13.5281 3.88463 12.6788 3.53284C11.8295 3.18106 10.9193 3 10 3C9.08075 3 8.1705 3.18106 7.32122 3.53284C6.47194 3.88463 5.70026 4.40024 5.05025 5.05025C4.40024 5.70026 3.88463 6.47194 3.53284 7.32122C3.18106 8.1705 3 9.08075 3 10Z"
            strokeWidth="1.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <path d="M10 3V17" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
          <path
            d="M10 7.66696L13.6167 4.05029"
            strokeWidth="1.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <path
            d="M10 11.7889L15.7322 6.05664"
            strokeWidth="1.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <path
            d="M10 15.9112L16.8833 9.02783"
            strokeWidth="1.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
        <svg
          className={classNames(!isChecked(mode, 'auto') && 'hidden')}
          width="20"
          height="20"
          viewBox="0 0 20 20"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            className="dark:fill-white fill-black/90"
            d="M14 3.07191C15.2162 3.77405 16.2261 4.78396 16.9282 6.00011C17.6304 7.21626 18 8.59582 18 10.0001C18 11.4044 17.6303 12.7839 16.9282 14.0001C16.226 15.2162 15.2161 16.2261 13.9999 16.9283C12.7837 17.6304 11.4042 18 9.99987 18C8.59557 18 7.21602 17.6303 5.99987 16.9281C4.78372 16.226 3.77383 15.216 3.07171 13.9999C2.36958 12.7837 1.99996 11.4041 2 9.99986L2.004 9.74066C2.0488 8.35906 2.45084 7.01265 3.17091 5.83268C3.89099 4.65271 4.90452 3.67946 6.11271 3.00781C7.3209 2.33616 8.68252 1.98903 10.0648 2.00026C11.4471 2.0115 12.8029 2.38071 14 3.07191ZM6.8 4.4575C5.57991 5.16199 4.62639 6.24939 4.08731 7.55104C3.54823 8.8527 3.45373 10.2959 3.81847 11.6567C4.1832 13.0175 4.98678 14.22 6.10458 15.0776C7.22238 15.9351 8.59192 16.3999 10.0008 16.3998L10 3.5999C8.87655 3.59995 7.77291 3.89573 6.8 4.4575Z"
          />
        </svg>
      </ToggleOption>
      <ToggleOption id="light" checked={isChecked(mode, 'light')} onChange={onSelect('light')}>
        <svg
          width="20"
          height="20"
          viewBox="0 0 20 20"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          className={classNames(
            isChecked(mode, 'light') && 'stroke-black/90',
            'dark:stroke-[#B8B4BF] stroke-black/70 hover:stroke-black hover:dark:stroke-white',
          )}
        >
          <path
            className={classNames(isChecked(mode, 'light') && 'fill-black/90')}
            d="M6.66602 10.0003C6.66602 10.8844 7.0172 11.7322 7.64233 12.3573C8.26745 12.9825 9.11529 13.3337 9.99935 13.3337C10.8834 13.3337 11.7313 12.9825 12.3564 12.3573C12.9815 11.7322 13.3327 10.8844 13.3327 10.0003C13.3327 9.11627 12.9815 8.26842 12.3564 7.6433C11.7313 7.01818 10.8834 6.66699 9.99935 6.66699C9.11529 6.66699 8.26745 7.01818 7.64233 7.6433C7.0172 8.26842 6.66602 9.11627 6.66602 10.0003Z"
            strokeWidth="1.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <path
            d="M2.5 10H3.33333M10 2.5V3.33333M16.6667 10H17.5M10 16.6667V17.5M4.66667 4.66667L5.25 5.25M15.3333 4.66667L14.75 5.25M14.75 14.75L15.3333 15.3333M5.25 14.75L4.66667 15.3333"
            strokeWidth="1.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </ToggleOption>
      <ToggleOption id="dark" checked={isChecked(mode, 'dark')} onChange={onSelect('dark')}>
        <div className="dark:stroke-[#B8B4BF] stroke-black/70 hover:stroke-black hover:dark:stroke-white">
          <svg
            width="20"
            height="20"
            viewBox="0 0 20 20"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              className={classNames(
                isChecked(mode, 'dark') && 'dark:fill-white dark:!stroke-white',
              )}
              d="M10.2374 3.54578C10.3289 3.54578 10.4197 3.54578 10.5098 3.54578C9.61926 4.4028 9.04684 5.55593 8.89205 6.80471C8.73725 8.05349 9.00987 9.31897 9.66251 10.3812C10.3152 11.4434 11.3065 12.2351 12.4644 12.6188C13.6222 13.0025 14.8732 12.9539 16 12.4814C15.5666 13.5615 14.8581 14.4995 13.9503 15.1954C13.0425 15.8913 11.9693 16.3188 10.8452 16.4325C9.72118 16.5462 8.5884 16.3417 7.56774 15.8409C6.54708 15.3401 5.67683 14.5618 5.04981 13.5889C4.42278 12.616 4.06251 11.4851 4.00743 10.3167C3.95234 9.14841 4.2045 7.98651 4.73702 6.95497C5.26953 5.92344 6.06242 5.06096 7.03111 4.45954C7.9998 3.85812 9.10796 3.54032 10.2374 3.54004V3.54578Z"
              strokeWidth="1.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </div>
      </ToggleOption>
    </ThreeStateToggle>
  );
};
