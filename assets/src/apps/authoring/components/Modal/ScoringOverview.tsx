import { setShowScoringOverview } from 'apps/authoring/store/app/slice';
import { savePage } from 'apps/authoring/store/page/actions/savePage';
import { selectState, updatePage } from 'apps/authoring/store/page/slice';
import { selectAllActivities } from 'apps/delivery/store/features/activities/slice';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { debounce } from 'lodash';
import React, { Fragment, useCallback, useEffect } from 'react';
import { FormControl, InputGroup, Modal, Table } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { clone } from 'utils/common';

const ScoringOverview: React.FC<{
  onClose?: () => void;
}> = ({ onClose }) => {
  const dispatch = useDispatch();

  const page = useSelector(selectState);
  const allActivities = useSelector(selectAllActivities);
  const sequence = useSelector(selectSequence);

  const [scoredActivities, setScoredActivities] = React.useState([]);

  useEffect(() => {
    if (!sequence || !allActivities) {
      return;
    }
    const scored = sequence.reduce((acc: any[], sequenceItem) => {
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
    }, []);

    setScoredActivities(scored);
  }, [allActivities, sequence]);

  const [enableLessonMax, setEnableLessonMax] = React.useState<boolean>(false);
  const [lessonMax, setLessonMax] = React.useState<number>(0);
  const [scoreSum, setScoreSum] = React.useState<number>(0);

  const handleEnableMaxChanged = React.useCallback(
    async (e: any) => {
      const checked = e.target.checked;
      setEnableLessonMax(checked);
      const customClone = clone(page.custom);
      customClone.scoreFixed = checked;
      if (checked) {
        customClone.totalScore = customClone.maxScore || lessonMax;
        setLessonMax(customClone.maxScore);
      } else {
        customClone.totalScore = scoreSum;
        // don't change the scoreMax so that it can be around for revert if they uncheck it
      }
      debounceSavePage(customClone);
    },
    [page, enableLessonMax, lessonMax, scoreSum],
  );

  const debounceSavePage = useCallback(
    debounce(
      (custom) => {
        console.log('debounceSavePage', custom);
        dispatch(savePage({ custom, undoable: true }));
        dispatch(updatePage({ custom }));
      },
      500,
      { trailing: true },
    ),
    [],
  );

  const handleMaxChanged = React.useCallback(
    async (e: any) => {
      const newValue = parseFloat(e.target.value);
      console.log('lesson max changed', newValue);
      setLessonMax(newValue);
      const customClone = clone(page.custom);
      if (enableLessonMax) {
        customClone.maxScore = newValue;
        customClone.totalScore = newValue;
        debounceSavePage(customClone);
      }
    },
    [page, enableLessonMax, lessonMax, scoreSum],
  );

  useEffect(() => {
    if (!page) {
      return;
    }
    let enableMax = false;
    if (typeof page.custom.scoreFixed === 'boolean') {
      enableMax = page.custom.scoreFixed;
    }

    setEnableLessonMax(enableMax);

    let max = page.custom.totalScore || 0;
    if (enableLessonMax && page.custom.maxScore) {
      max = page.custom.maxScore;
    }
    setLessonMax(max);
  }, [page]);

  useEffect(() => {
    const sum = scoredActivities.reduce((acc: number, activity: any) => {
      return acc + activity.maxScore;
    }, 0);
    setScoreSum(sum);
    let max = scoreSum;
    if (enableLessonMax && page.custom.maxScore) {
      max = page.custom.maxScore;
    }
    setLessonMax(max);
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
              <InputGroup.Checkbox checked={enableLessonMax} onChange={handleEnableMaxChanged} />
            </InputGroup.Prepend>
            <FormControl
              type="number"
              readOnly={!enableLessonMax}
              value={lessonMax}
              onChange={handleMaxChanged}
            />
          </InputGroup>
        </Modal.Body>
      </Modal>
    </Fragment>
  );
};

export default ScoringOverview;
