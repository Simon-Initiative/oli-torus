import React from 'react';
import { SolutionProps } from './SolutionProps';

export const FixIdButton: React.FC<SolutionProps> = ({
  suggestion,
  onClick,
}: SolutionProps): JSX.Element => {
  const txtRef = React.useRef<HTMLInputElement>(null);

  const handleClick = () => {
    if (txtRef.current && onClick) {
      const newVal = txtRef.current.value;
      onClick(newVal);
    }
  };

  return (
    <>
      <input ref={txtRef} type="text" defaultValue={suggestion} />
      <button className="btn btn-sm btn-primary" onClick={handleClick}>
        Apply
      </button>
    </>
  );
};

export default FixIdButton;
