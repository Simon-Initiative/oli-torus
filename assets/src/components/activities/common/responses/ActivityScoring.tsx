import React, {  useState } from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { HasParts } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { getIncorrectPoints, getOutOfPoints } from 'data/activities/model/responses';
import { ScoringActions } from '../authoring/actions/scoringActions';
import { ScoreInput } from './ScoreInput';

interface ActivityScoreProps {
  partId: string;
}

export const ActivityScoring: React.FC<ActivityScoreProps> = ({ partId }) => {
  const { model, dispatch, editMode } = useAuthoringElementContext<HasParts>();
  const checkboxInputId = `scoring-${partId}`;
  const outOf = getOutOfPoints(model, partId);
  const incorrect = getIncorrectPoints(model, partId);
  const [useDefaultScoring, setDefaultScoring] = useState(outOf === null);
  const outOfPoints = outOf || 1;
  const incorrectPoints = incorrect || 0;

  const onChangeDefault = (e: React.ChangeEvent<HTMLInputElement>) => {
    setDefaultScoring(e.target.checked);
    if (e.target.checked) {
      dispatch(ScoringActions.editPartScore(partId, null, null));
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

  return (
    <Card.Card>
      <Card.Title>Scoring</Card.Title>
      <Card.Content>
        <div className="mb-2">
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
          <div className='flex flex-row gap-4'>
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
        )}
      </Card.Content>
    </Card.Card>
  );
};

