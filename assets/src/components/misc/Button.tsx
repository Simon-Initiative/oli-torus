import React from 'react';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary';
}

type ColorSchemes = 'primary-disabled' | 'primary' | 'secondary' | 'secondary-disabled';

const variantColorSchemes: Record<ColorSchemes, string> = {
  'primary-disabled': 'torus-primary-disabled bg-delivery-primary-200 text-delivery-body',
  primary:
    'torus-primary bg-delivery-primary hover:bg-delivery-primary-300 text-delivery-body active:bg-delivery-primary-600',
  secondary:
    'torus-secondary bg-delivery-secondary hover:bg-gray-100 text-delivery-primary active:bg-gray-200',
  'secondary-disabled': 'torus-secondary-disabled bg-delivery-secondary text-delivery-primary-300 ',
};

export const LargeButton: React.FC<ButtonProps> = ({ className, children, ...other }) => (
  <BaseButton className={`torus-button px-5 py-3 ${className}`} {...other}>
    {children}
  </BaseButton>
);

LargeButton.defaultProps = {
  variant: 'primary',
};

export const Button: React.FC<ButtonProps> = ({ children, className, ...other }) => (
  <BaseButton className={`px-3 py-1 ${className}`} {...other}>
    {children}
  </BaseButton>
);

Button.defaultProps = {
  variant: 'primary',
};

export const BaseButton: React.FC<ButtonProps> = ({ variant, children, className, ...other }) => {
  const scheme = (variant + (other.disabled ? '-disabled' : '')) as ColorSchemes;
  return (
    <button className={`${variantColorSchemes[scheme]} rounded-md mx-1 ${className} `} {...other}>
      {children}
    </button>
  );
};

BaseButton.defaultProps = {
  variant: 'primary',
};
