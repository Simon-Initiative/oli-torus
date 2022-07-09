import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { MultiInputActions } from 'components/activities/vlab/actions';
import { friendlyVlabParameter } from 'components/activities/vlab/utils';
import { VlabValue, VlabSchema } from 'components/activities/vlab/schema';
import React from 'react';

interface Props {
  input: VlabValue;
}

const paramList = ['volume', 'temp', 'moles', 'mass'];

export const VlabParameterSelector: React.FC<Props> = (props) => {
  const { model, dispatch } = useAuthoringElementContext<VlabSchema>();
  return (
    <>
      <div>The currently selected parameter is {friendlyVlabParameter(props.input.parameter)}.</div>
      {paramList.map((param, i) => (
        <div key={i}>
          <label>
            <input
              type="radio"
              name="vlparam"
              value={param}
              checked={param === props.input.parameter}
              onChange={() => dispatch(MultiInputActions.setVlabParameter(props.input.id, param))}
            />
            {friendlyVlabParameter(param)}
          </label>
        </div>
      ))}
      <div>
        <label>
          <input
            type="text"
            name="speciesID"
            value={props.input.species}
            disabled={props.input.parameter !== 'moles' && props.input.parameter !== 'mass'}
            onChange={(e) =>
              dispatch(MultiInputActions.setVlabSpecies(props.input.id, e.target.value))
            }
          />
          Species ID
        </label>
      </div>
    </>
  );
};
