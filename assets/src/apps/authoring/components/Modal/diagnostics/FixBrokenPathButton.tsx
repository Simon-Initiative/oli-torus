import React from 'react';
import guid from 'utils/guid';
import { SolutionProps } from './SolutionProps';
import ScreenDropdownTemplate from '../../PropertyEditor/custom/ScreenDropdownTemplate';

export const FixBrokenPathButton: React.FC<SolutionProps> = ({
  onClick,
}: SolutionProps): JSX.Element => {
  const [target, setTarget] = React.useState('invalid');

  const uuid = guid();

  const handleClick = () => {
    if (target !== 'invalid') {
      onClick(target);
    }
  };

  const onChangeHandler = (sequenceId: string) => {
    // console.log('onChange picker', sequenceId);
    // onClick(sequenceId);
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
      <button className="btn btn-sm btn-primary ml-2" onClick={handleClick}>
        Apply
      </button>
    </div>
  );
};
