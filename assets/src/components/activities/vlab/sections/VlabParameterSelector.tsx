import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { VlabActions } from 'components/activities/vlab/actions';
import { friendlyVlabParameter } from 'components/activities/vlab/utils';
import { VlabValue, VlabSchema } from 'components/activities/vlab/schema';
import React from 'react';

interface Props {
  input: VlabValue;
}

const paramList = ['volume', 'temp', 'pH', 'moles', 'mass', 'molarity', 'concentration'];

export const VlabParameterSelector: React.FC<Props> = (props) => {
  const { model, dispatch } = useAuthoringElementContext<VlabSchema>();
  return (
    <>
      <div>
        <p>
          Choose the property of the selected vessel that is to be tested. For the properties moles,
          mass, molarity and concetration, you must also supply the relevant species ID.
        </p>
      </div>
      <div className="form-check">
        {paramList.map((param, i) => (
          <div key={i}>
            <label className="form-check-label">
              <input
                className="form-check-input"
                type="radio"
                name={'vlparam_' + model.stem.id}
                value={param}
                checked={param === props.input.parameter}
                onChange={() => dispatch(VlabActions.setVlabParameter(props.input.id, param))}
              />
              {friendlyVlabParameter(param)}
            </label>
          </div>
        ))}
      </div>
      <div className="form-label-group">
        <label>
          <input
            type="text"
            name="speciesID"
            value={props.input.species}
            disabled={
              props.input.parameter === 'volume' ||
              props.input.parameter === 'temp' ||
              props.input.parameter === 'pH'
            }
            onChange={(e) => dispatch(VlabActions.setVlabSpecies(props.input.id, e.target.value))}
          />
          Species ID
        </label>
      </div>
    </>
  );
};
