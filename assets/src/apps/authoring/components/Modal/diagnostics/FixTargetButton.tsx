import React, { useRef, useState } from 'react';
import guid from 'utils/guid';
import { OverlayPlacements, VariablePicker } from '../../AdaptivityEditor/VariablePicker';
import { useDiagnosticsOverlay } from '../DiagnosticsOverlayContext';
import { SolutionProps } from './SolutionProps';

export const FixTargetButton: React.FC<SolutionProps> = ({
  suggestion,
  onClick,
}: SolutionProps): JSX.Element => {
  const targetRef = useRef<HTMLInputElement>(null);
  const typeRef = useRef<HTMLSelectElement>(null);
  const { overlayContainer } = useDiagnosticsOverlay();
  const [isApplying, setIsApplying] = useState(false);

  const uuid = guid();

  const handleClick = async () => {
    if (!targetRef.current || !onClick || isApplying) {
      return;
    }
    setIsApplying(true);
    try {
      await onClick(targetRef.current.value);
    } finally {
      setIsApplying(false);
    }
  };

  const handleTargetChange = (val: string) => {
    if (targetRef.current) {
      targetRef.current.value = val;
    }
  };

  return (
    <div className="aa-action aa-mutate d-flex mb-2 form-inline align-items-center flex-nowrap">
      <label className="sr-only" htmlFor={`action-mutate-target-${uuid}`}>
        target
      </label>
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend" title="target">
          <VariablePicker
            onTargetChange={(value) => handleTargetChange(value)}
            targetRef={targetRef}
            typeRef={typeRef}
            placement={OverlayPlacements.TOP}
            context="mutate"
            overlayContainer={overlayContainer}
          />
        </div>
        <input
          type="text"
          className="form-control form-control-sm mr-2 flex-grow-1"
          id={`action-mutate-target-${uuid}`}
          defaultValue={suggestion}
          onBlur={(e) => handleTargetChange(e.target.value)}
          title={suggestion}
          placeholder="Target"
          ref={targetRef}
          disabled={isApplying}
        />
      </div>
      <button
        className="btn btn-sm btn-primary diagnostics-hub__apply-btn"
        onClick={handleClick}
        disabled={isApplying}
      >
        {isApplying ? (
          <i className="fa fa-spinner fa-spin" aria-hidden="true" />
        ) : (
          'Apply'
        )}
      </button>
    </div>
  );
};

export default FixTargetButton;
