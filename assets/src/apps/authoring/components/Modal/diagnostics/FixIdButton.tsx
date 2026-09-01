import React, { useState } from 'react';
import { SolutionProps } from './SolutionProps';

export const FixIdButton: React.FC<SolutionProps> = ({
  suggestion,
  onClick,
}: SolutionProps): JSX.Element => {
  const txtRef = React.useRef<HTMLInputElement>(null);
  const [isApplying, setIsApplying] = useState(false);

  const handleClick = async () => {
    if (!txtRef.current || !onClick || isApplying) {
      return;
    }
    setIsApplying(true);
    try {
      await onClick(txtRef.current.value);
    } finally {
      setIsApplying(false);
    }
  };

  return (
    <div className="aa-action aa-mutate d-flex mb-2 form-inline align-items-center flex-nowrap">
      <input
        ref={txtRef}
        type="text"
        defaultValue={suggestion}
        className="form-control form-control-sm"
        disabled={isApplying}
      />
      <button
        className="btn btn-sm btn-primary ml-2 diagnostics-hub__apply-btn"
        onClick={handleClick}
        disabled={isApplying}
      >
        {isApplying ? <i className="fa fa-spinner fa-spin" aria-hidden="true" /> : 'Apply'}
      </button>
    </div>
  );
};

export default FixIdButton;
