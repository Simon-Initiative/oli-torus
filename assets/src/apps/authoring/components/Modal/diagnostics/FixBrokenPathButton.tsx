import React, { useState } from 'react';
import guid from 'utils/guid';
import ScreenDropdownTemplate from '../../PropertyEditor/custom/ScreenDropdownTemplate';
import { SolutionProps } from './SolutionProps';

export const FixBrokenPathButton: React.FC<SolutionProps> = ({
  onClick,
}: SolutionProps): JSX.Element => {
  const [target, setTarget] = React.useState('invalid');
  const [isApplying, setIsApplying] = useState(false);

  const uuid = guid();

  const handleClick = async () => {
    if (target === 'invalid' || !onClick || isApplying) {
      return;
    }
    setIsApplying(true);
    try {
      await onClick(target);
    } finally {
      setIsApplying(false);
    }
  };

  const onChangeHandler = (sequenceId?: string) => {
    setTarget(sequenceId || 'invalid');
  };

  return (
    <div className="aa-action d-flex mb-2 form-inline align-items-center flex-nowrap">
      <label className="sr-only" htmlFor={`action-navigation-${uuid}`}>
        SequenceId
      </label>
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend">
          <div className="input-group-text">
            <i className="fa fa-compass mr-1" />
            Navigate To
          </div>
        </div>
        <ScreenDropdownTemplate
          id={`action-navigation-${uuid}`}
          label=""
          value={target}
          onChange={onChangeHandler}
          dropDownCSSClass=""
          buttonCSSClass="form-control-sm"
        />
      </div>
      <button
        className="btn btn-sm btn-primary ml-2 diagnostics-hub__apply-btn"
        onClick={handleClick}
        disabled={isApplying || target === 'invalid'}
      >
        {isApplying ? <i className="fa fa-spinner fa-spin" aria-hidden="true" /> : 'Apply'}
      </button>
    </div>
  );
};
