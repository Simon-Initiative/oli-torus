import { SolutionProps } from './SolutionProps';
import React from 'react';

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
    <div className="aa-action aa-mutate d-flex mb-2 form-inline align-items-center flex-nowrap">
      <input
        ref={txtRef}
        type="text"
        defaultValue={suggestion}
        className="form-control form-control-sm"
      />
      <button className="btn btn-sm btn-primary ml-2" onClick={handleClick}>
        Apply
      </button>
    </div>
  );
};

export default FixIdButton;
