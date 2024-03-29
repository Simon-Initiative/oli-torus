import React, { useRef, useState } from 'react';
import guid from 'utils/guid';
import { OverlayPlacements, VariablePicker } from '../../AdaptivityEditor/VariablePicker';
import { SolutionProps } from './SolutionProps';

export const FixTargetButton: React.FC<SolutionProps> = ({
  onClick,
}: SolutionProps): JSX.Element => {
  const targetRef = useRef<HTMLInputElement>(null);
  const typeRef = useRef<HTMLSelectElement>(null);

  const [target, setTarget] = useState();
  const [_isDirty, setIsDirty] = useState(false);

  const uuid = guid();

  const handleClick = () => {
    if (targetRef.current && onClick) {
      const newVal = targetRef.current.value;
      onClick(newVal);
    }
  };

  const handleTargetChange = (val: any) => {
    setTarget(val);
    setIsDirty(true);
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
            typeRef={typeRef}
            placement={OverlayPlacements.TOP}
            context="mutate"
          />
        </div>
        <input
          type="text"
          className="form-control form-control-sm mr-2 flex-grow-1"
          id={`action-mutate-target-${uuid}`}
          defaultValue={target}
          onBlur={(e) => handleTargetChange(e.target.value)}
          title={target}
          placeholder="Target"
          ref={targetRef}
        />
      </div>
      <button className="btn btn-sm btn-primary" onClick={handleClick}>
        Apply
      </button>
    </div>
  );
};

export default FixTargetButton;
