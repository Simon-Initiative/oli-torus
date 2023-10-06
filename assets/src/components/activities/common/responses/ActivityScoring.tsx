import React, { useMemo, useState } from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { HasParts, ScoringStrategy } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import {
  getIncorrectPoints,
  getOutOfPoints,
  getScoringStrategy,
} from 'data/activities/model/responses';
import guid from 'utils/guid';
import { ScoringActions } from '../authoring/actions/scoringActions';
import { ScoreInput } from './ScoreInput';

interface ActivityScoreProps {
  partId: string;
  shouldSetStrategy?: boolean;
}

/*
  Sets a single part-level score for the activity. Not appropriate for activities with multiple parts.
*/
export const ActivityScoring: React.FC<ActivityScoreProps> = ({ partId, shouldSetStrategy }) => {
  const { model, dispatch, editMode } = useAuthoringElementContext<HasParts>();
  const checkboxInputId = useMemo(() => guid(), []);
  const outOf = getOutOfPoints(model, partId);
  const incorrect = getIncorrectPoints(model, partId);
  const [useDefaultScoring, setDefaultScoring] = useState(outOf === null || outOf === undefined);
  const outOfPoints = outOf || 1;
  const incorrectPoints = incorrect || 0;
  const scoringStrategy = getScoringStrategy(model, partId);

  const onChangeDefault = (e: React.ChangeEvent<HTMLInputElement>) => {
    setDefaultScoring(e.target.checked);
    if (e.target.checked) {
      dispatch(ScoringActions.editPartScore(partId, null, null));
      dispatch(ScoringActions.editPartScoringStrategy(partId, 'average'));
    } else {
      dispatch(ScoringActions.editPartScore(partId, 1, 0));
    }
  };

  const onCorrectScoreChange = (score: number) => {
    if (score >= 0) {
      dispatch(ScoringActions.editPartScore(partId, score, incorrectPoints || null));
    }
  };

  const onIncorrectScoreChange = (score: number) => {
    if (score >= 0) {
      dispatch(ScoringActions.editPartScore(partId, outOf || null, score));
    }
  };

  const onScoringStrategyChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    dispatch(ScoringActions.editPartScoringStrategy(partId, e.target.value as ScoringStrategy));
  };

  return (
    <Card.Card>
      <Card.Title>Scoring</Card.Title>
      <Card.Content>
        <div className="mb-4">
          <input
            className="mr-2"
            type="checkbox"
            aria-label="Checkbox for default scoring"
            onChange={onChangeDefault}
            checked={useDefaultScoring}
            id={checkboxInputId}
            disabled={!editMode}
          />
          <label className="mt-2 form-check-label" htmlFor={checkboxInputId}>
            Use default scoring
          </label>
        </div>

        {useDefaultScoring || (
          <>
            <div className="flex flex-row gap-4">
              <ScoreInput score={outOfPoints} onChange={onCorrectScoreChange} editMode={editMode}>
                Correct Answer Score:
              </ScoreInput>

              <ScoreInput
                score={incorrectPoints}
                onChange={onIncorrectScoreChange}
                editMode={editMode}
              >
                Incorrect Answer Score:
              </ScoreInput>
            </div>
            {shouldSetStrategy && (
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
          </>
        )}
      </Card.Content>
    </Card.Card>
  );
};

ActivityScoring.defaultProps = {
  shouldSetStrategy: false,
};
