import React, { useMemo } from 'react';
import { Card } from 'components/misc/Card';
import { multiHasCustomScoring } from 'data/activities/model/responses';
import guid from 'utils/guid';
import { useAuthoringElementContext } from '../AuthoringElementProvider';
import { ScoringActions } from '../common/authoring/actions/scoringActions';
import { ScoringStrategy } from '../types';
import { ResponseMultiInputSchema } from './schema';

interface ResponseMultiInputScoringMethodProps {}

export const ResponseMultiInputScoringMethod: React.FC<
  ResponseMultiInputScoringMethodProps
> = () => {
  const { model, dispatch, editMode } = useAuthoringElementContext<ResponseMultiInputSchema>();
  const checkboxInputId = useMemo(guid, []);
  const defaultScoring = !multiHasCustomScoring(model);
  const scoringStrategy = model.scoringStrategy || ScoringStrategy.total;

  const onChangeDefault = (e: React.ChangeEvent<HTMLInputElement>) => {
    dispatch(ScoringActions.toggleActivityDefaultScoring());
  };

  const onScoringStrategyChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    dispatch(ScoringActions.editActivityScoringStrategy(e.target.value as ScoringStrategy));
  };

  return (
    <Card.Card>
      <Card.Title>Activity Scoring Method</Card.Title>
      <Card.Content>
        <div className="mb-4">
          <input
            className="mr-2"
            type="checkbox"
            aria-label="Checkbox for default scoring"
            onChange={onChangeDefault}
            checked={defaultScoring}
            id={checkboxInputId}
            disabled={!editMode}
          />
          <label className="mt-2 form-check-label" htmlFor={checkboxInputId}>
            Use default scoring
          </label>
        </div>

        {defaultScoring || (
          <div className="flex flex-row gap-4 mt-4 items-center">
            <label className="flex items-center">Scoring Strategy</label>
            <select
              style={{ width: '40%' }}
              className="form-control"
              disabled={!editMode}
              value={scoringStrategy || 'average'}
              onChange={onScoringStrategyChange}
            >
              <option value="average">Average</option>
              <option value="total">Total</option>
              <option value="best">Best</option>
            </select>
          </div>
        )}
      </Card.Content>
    </Card.Card>
  );
};
