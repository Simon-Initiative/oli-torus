import React from 'react';

export const TechSupportButton = () => (
  <button
    className="
              mx-auto
              block
              no-underline
              text-delivery-body-color
              dark:text-delivery-body-color-dark
              hover:no-underline
              border-b
              border-transparent
              hover:text-delivery-primary
              dark:hover:text-delivery-primary:text-delivery-primary
              active:text-delivery-primary-600
              active:hover:text-delivery-primary-600
            "
    onClick={() => (window as any).showHelpModal()}
  >
    Tech Support
  </button>
);
