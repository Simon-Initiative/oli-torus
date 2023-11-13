import React from 'react';

export const DiscussionPortrait: React.FC = () => (
  <>
    <Bullet />
    <svg width="28" height="28" viewBox="0 0 28 28" fill="none" xmlns="http://www.w3.org/2000/svg">
      <g clipPath="url(#clip0_17_64)">
        <path
          d="M14 2.33333C7.56004 2.33333 2.33337 7.56 2.33337 14C2.33337 20.44 7.56004 25.6667 14 25.6667C20.44 25.6667 25.6667 20.44 25.6667 14C25.6667 7.56 20.44 2.33333 14 2.33333ZM14 7C16.2517 7 18.0834 8.83166 18.0834 11.0833C18.0834 13.335 16.2517 15.1667 14 15.1667C11.7484 15.1667 9.91671 13.335 9.91671 11.0833C9.91671 8.83166 11.7484 7 14 7ZM14 23.3333C11.6317 23.3333 8.83171 22.3767 6.83671 19.9733C8.80837 18.4333 11.2934 17.5 14 17.5C16.7067 17.5 19.1917 18.4333 21.1634 19.9733C19.1684 22.3767 16.3684 23.3333 14 23.3333Z"
          fill="black"
        />
      </g>
      <defs>
        <clipPath id="clip0_17_64">
          <rect width="28" height="28" fill="white" />
        </clipPath>
      </defs>
    </svg>
  </>
);

const Bullet: React.FC = () => (
  <svg className='absolute top-2 left-[-10px]' width="5" height="5" viewBox="0 0 5 5" fill="none" xmlns="http://www.w3.org/2000/svg">
    <circle cx="2.5" cy="2.5" r="2" fill="white" stroke="black" />
  </svg>
);
