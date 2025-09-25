import React, { useMemo, useState } from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { HasParts } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import {
  getIncorrectPoints,
  getOutOfPoints,
  hasCustomScoring,
} from 'data/activities/model/responses';
import guid from 'utils/guid';
import { ScoringActions } from '../authoring/actions/scoringActions';
import { ScoreInput } from './ScoreInput';

interface ActivityScoreProps {
  partId: string;
  promptForDefault?: boolean; // Should we display the "use default scoring" checkbox?
}

/*
  Sets a single part-level score for the activity. Not appropriate for activities with multiple parts.
*/
export const ActivityScoring: React.FC<ActivityScoreProps> = ({ partId, promptForDefault }) => {
  const { model, dispatch, editMode } = useAuthoringElementContext<HasParts>();
  const checkboxInputId = useMemo(() => guid(), []);
  const outOfPoints = getOutOfPoints(model, partId);
  const incorrectPoints = getIncorrectPoints(model, partId);
  const [useDefaultScoring, setDefaultScoring] = useState(
    !hasCustomScoring(model) && promptForDefault,
  );

  const onChangeDefault = (e: React.ChangeEvent<HTMLInputElement>) => {
    setDefaultScoring(e.target.checked);
    if (e.target.checked) {
      // custom to default: sets outOf to null to indicate
      dispatch(ScoringActions.editPartScore(partId, null, null, 'average'));
    } else {
      // default to custom
      dispatch(ScoringActions.editPartScore(partId, 1, 0));
    }
  };

  const onCorrectScoreChange = (score: number) => {
    // disallow changing correct to zero, can cause problems finding correct answer on migrated qs
    if (score > 0) {
      dispatch(ScoringActions.editPartScore(partId, score, incorrectPoints || null));
    }
  };

  const onIncorrectScoreChange = (score: number) => {
    if (score >= 0) {
      dispatch(ScoringActions.editPartScore(partId, outOfPoints, score));
    }
  };

  return (
    <Card.Card>
      <Card.Title>Scoring</Card.Title>
      <Card.Content>
        {promptForDefault && (
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
        )}

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
          </>
        )}
      </Card.Content>
    </Card.Card>
  );
};

ActivityScoring.defaultProps = {
  promptForDefault: true,
};
