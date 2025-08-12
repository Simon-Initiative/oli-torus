import React, { Fragment, useCallback, useEffect } from 'react';
import { FormControl, InputGroup, Modal, Table } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { debounce } from 'lodash';
import { selectAllObjectivesMap, setShowScoringOverview } from 'apps/authoring/store/app/slice';
import { savePage } from 'apps/authoring/store/page/actions/savePage';
import { selectState, updatePage } from 'apps/authoring/store/page/slice';
import { IActivity, selectAllActivities } from 'apps/delivery/store/features/activities/slice';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { clone } from 'utils/common';
import { Objective } from '../../../../data/content/objective';
import { AdvancedAuthoringModal } from '../AdvancedAuthoringModal';

interface ScoredActivity {
  sequenceId: number;
  sequenceName: string;
  resourceId: number;
  maxScore: number;
  scoreType: string;
  objectives: Record<string, Objective>;
}

const ScoringOverview: React.FC<{
  onClose?: () => void;
}> = ({ onClose }) => {
  const dispatch = useDispatch();

  const page = useSelector(selectState);
  const allActivities = useSelector(selectAllActivities);
  const sequence = useSelector(selectSequence);

  const [scoredActivities, setScoredActivities] = React.useState<ScoredActivity[]>([]);

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

      const manualGradingDetails = (activity.authoring?.parts || []).reduce(
        (gradingDetails: { manuallyGraded: boolean; maxManualScore: number }, part: any) => {
          const partIsManuallyGraded = part.gradingApproach === 'manual';
          if (partIsManuallyGraded) {
            gradingDetails.manuallyGraded = true;
            gradingDetails.maxManualScore += part.outOf || 0;
          }
          return gradingDetails;
        },
        { manuallyGraded: false, maxManualScore: 0 },
      );

      const isScored =
        maxScore > 0 ||
        (manualGradingDetails.manuallyGraded && manualGradingDetails.maxManualScore > 0);

      if (isScored) {
        const scoringMax = maxScore > 0 ? maxScore : manualGradingDetails.maxManualScore;

        const scoreSchemeText = trapStateScoreScheme ? 'Trap State' : `Attempts (${maxAttempt})`;
        const scoreType = manualGradingDetails.manuallyGraded ? 'Manually Graded' : scoreSchemeText;

        acc.push({
          sequenceId: sequenceItem.custom.sequenceId,
          sequenceName: sequenceItem.custom.sequenceName,
          resourceId: sequenceItem.resourceId,
          objectives: activity.objectives,
          maxScore: scoringMax,
          scoreType,
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
    const sum = scoredActivities.reduce((acc: number, activity: ScoredActivity) => {
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
      <AdvancedAuthoringModal
        className="advance-author-scoring-overview"
        show={true}
        size="xl"
        onHide={handleClose}
      >
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
                <th>Objectives</th>
              </tr>
            </thead>
            <tbody>
              {scoredActivities &&
                scoredActivities.map((activity: any) => (
                  <tr key={activity.sequenceId}>
                    <td>{activity.sequenceName}</td>
                    <td>{activity.maxScore}</td>
                    <td>{activity.scoreType}</td>
                    <td>
                      <LearningObjectivesList activity={activity} />
                    </td>
                  </tr>
                ))}
              {(!scoredActivities || !scoredActivities.length) && (
                <tr>
                  <td colSpan={4}>None</td>
                </tr>
              )}
            </tbody>
          </Table>
          <hr />
          <InputGroup.Text>Sum of All Scores: {scoreSum}</InputGroup.Text>
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
      </AdvancedAuthoringModal>
    </Fragment>
  );
};

const LearningObjectivesList: React.FC<{ activity: IActivity }> = ({ activity }) => {
  const objectiveMap = useSelector(selectAllObjectivesMap);
  const allObjectives = Object.values(activity.objectives || {}).flat();
  if (allObjectives.length === 0) {
    return null;
  }
  return (
    <ul className="list-unstyled">
      {allObjectives.map((objectiveId: number) => {
        const objectiveLabel = objectiveMap[objectiveId]
          ? objectiveMap[objectiveId].title
          : `Unknown Objective ${objectiveId}`;
        return <li key={objectiveId}>{objectiveLabel}</li>;
      })}
    </ul>
  );
};

export default ScoringOverview;
