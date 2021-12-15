import { setShowScoringOverview } from 'apps/authoring/store/app/slice';
import { selectState } from 'apps/authoring/store/page/slice';
import { selectAllActivities } from 'apps/delivery/store/features/activities/slice';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import React, { Fragment, useEffect } from 'react';
import { FormControl, InputGroup, Modal, Table } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';

const ScoringOverview: React.FC<{
  onClose?: () => void;
}> = ({ onClose }) => {
  const dispatch = useDispatch();

  const page = useSelector(selectState);
  const allActivities = useSelector(selectAllActivities);
  const sequence = useSelector(selectSequence);

  const scoredActivities =
    sequence && allActivities
      ? sequence.reduce((acc: any[], sequenceItem) => {
          if (sequenceItem.custom.isLayer || sequenceItem.custom.isBank) {
            return acc;
          }
          const activity = allActivities.find((a) => a.id === sequenceItem.resourceId);
          if (!activity) {
            return acc;
          }
          const { maxAttempt, maxScore, trapStateScoreScheme } = activity.content?.custom;

          if (maxScore > 0) {
            acc.push({
              sequenceId: sequenceItem.custom.sequenceId,
              sequenceName: sequenceItem.custom.sequenceName,
              resourceId: sequenceItem.resourceId,
              maxScore,
              scoreType: trapStateScoreScheme ? 'Trap State' : `Attempts (${maxAttempt})`,
            });
          }

          return acc;
        }, [])
      : [];

  const [enableLessonMax, setEnableLessonMax] = React.useState<boolean>(false);
  const [lessonMax, setLessonMax] = React.useState<number>(0);
  const [scoreSum, setScoreSum] = React.useState<number>(0);

  useEffect(() => {
    if (!page) {
      return;
    }
    let enableMax = false;
    if (typeof page.custom.lessonMax === 'boolean') {
      enableMax = page.custom.lessonMax;
    } else if (typeof page.custom.scoreFixed === 'boolean') {
      enableMax = page.custom.scoreFixed;
    }

    setEnableLessonMax(enableMax);

    if (enableMax) {
      const max = page.custom.lessonMax || page.custom.totalScore || 0;
      setLessonMax(max);
    }
  }, [page]);

  useEffect(() => {
    const sum = scoredActivities.reduce((acc: number, activity: any) => {
      return acc + activity.maxScore;
    }, 0);
    setScoreSum(sum);
    if (enableLessonMax) {
      const max = page.custom.lessonMax || page.custom.totalScore || scoreSum;
      setLessonMax(max);
    }
  }, [scoredActivities, enableLessonMax]);

  const handleClose = () => {
    if (onClose) {
      onClose();
    }
    dispatch(setShowScoringOverview({ show: false }));
  };

  return (
    <Fragment>
      <Modal show={true} size="lg" onHide={handleClose}>
        <Modal.Header closeButton={true}>
          <h3 className="modal-title">Scoring Overview</h3>
        </Modal.Header>
        <Modal.Body>
          <Table striped bordered hover>
            <thead>
              <tr>
                <th>Screen</th>
                <th>Max Score</th>
                <th>Method</th>
              </tr>
            </thead>
            <tbody>
              {scoredActivities &&
                scoredActivities.map((activity: any) => (
                  <tr key={activity.sequenceId}>
                    <td>{activity.sequenceName}</td>
                    <td>{activity.maxScore}</td>
                    <td>{activity.scoreType}</td>
                  </tr>
                ))}
              {(!scoredActivities || !scoredActivities.length) && (
                <tr>
                  <td colSpan={3}>None</td>
                </tr>
              )}
            </tbody>
          </Table>
          <hr />
          <div>Sum of All Scores: {scoreSum}</div>
          <InputGroup className="mb-3">
            <InputGroup.Prepend>
              <InputGroup.Text>Lesson Max</InputGroup.Text>
              <InputGroup.Checkbox
                onChange={(e: any) => {
                  setEnableLessonMax(e.target.checked);
                }}
              />
            </InputGroup.Prepend>
            <FormControl
              type="number"
              readOnly={!enableLessonMax}
              value={lessonMax}
              onChange={(e) => {
                setLessonMax(parseFloat(e.target.value));
              }}
            />
          </InputGroup>
        </Modal.Body>
      </Modal>
    </Fragment>
  );
};

export default ScoringOverview;
