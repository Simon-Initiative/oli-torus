import { selectReadOnly, setShowDiagnosticsWindow } from 'apps/authoring/store/app/slice';
import { setCurrentActivityFromSequence } from 'apps/authoring/store/groups/layouts/deck/actions/setCurrentActivityFromSequence';
import { validatePartIds } from 'apps/authoring/store/groups/layouts/deck/actions/validate';
import DiagnosticMessage from './diagnostics/DiagnosticMessage';
import { DiagnosticTypes, DiagnosticRuleTypes } from './diagnostics/DiagnosticTypes';

import { setCurrentSelection } from 'apps/authoring/store/parts/slice';
import React, { Fragment, useState } from 'react';
import { ListGroup, Modal } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { createUpdater } from './diagnostics/actions';
import { DiagnosticSolution } from './diagnostics/DiagnosticSolution';
import { selectAllActivities } from 'apps/delivery/store/features/activities/slice';
import { setCurrentRule } from '../../store/app/slice';
import { AdaptiveRule } from '../AdaptiveRulesList/AdaptiveRulesList';

const ActivityPartError: React.FC<{ error: any; onApplyFix: () => void }> = ({
  error,
  onApplyFix,
}) => {
  const dispatch = useDispatch();
  const isReadOnlyMode = useSelector(selectReadOnly);
  const currentActivities = useSelector(selectAllActivities);

  const handleClickScreen = (sequenceId: string) => {
    dispatch(setCurrentActivityFromSequence(sequenceId));
  };

  const getOwnerName = (dupe: any) => {
    const screen = error.activity;
    if (dupe.owner.custom.sequenceId === screen.custom.sequenceId) {
      return 'self';
    }
    if (dupe.owner.custom.sequenceId === screen.custom.layerRef) {
      return `${dupe.owner.custom.sequenceName} (Parent)`;
    }
    return dupe.owner.custom.sequenceName;
  };

  let errorTotals = '';
  const dupes = error.problems.filter((p: any) => p.type === 'duplicate');
  const pattern = error.problems.filter((p: any) => p.type === 'pattern');
  const broken = error.problems.filter((p: any) => p.type === 'broken');
  if (dupes.length) {
    errorTotals += `${dupes.length} components with duplicate IDs found.\n`;
  }
  if (pattern.length) {
    errorTotals += `${pattern.length} components with problematic IDs found.\n`;
  }
  if (broken.length) {
    errorTotals += `${broken.length} components with broken paths found.\n`;
  }

  const handleProblemFix = async (fixed: string, problem: any) => {
    await dispatch(setCurrentSelection(''));
    const updater = createUpdater(problem.type)(problem, fixed, currentActivities);
    const result = await dispatch(updater);

    const ruleId =
      problem.type === DiagnosticTypes.INVALID_TARGET_MUTATE
        ? problem.item.id
        : problem.type === DiagnosticTypes.INVALID_TARGET_COND
        ? problem.item.rule.id
        : problem.type === DiagnosticTypes.INVALID_VALUE
        ? problem.item.rule.id
        : 'initState';

    const activity = result.meta.arg.activity;
    const rule = activity.authoring.rules.find((rule: AdaptiveRule) => rule.id === ruleId);

    // TODO: something if it fails
    dispatch(setCurrentRule({ currentRule: rule }));
    onApplyFix();
  };

  const getCurrentRule = (problem: any) => {
    switch (problem.type) {
      case DiagnosticTypes.INVALID_TARGET_INIT:
        return 'initState';
      case DiagnosticTypes.INVALID_TARGET_COND:
      case DiagnosticTypes.INVALID_VALUE:
        return problem.item.rule;
      case DiagnosticTypes.INVALID_TARGET_MUTATE:
        return problem.item;
    }
  };

  const handleProblemClick = async (problem: any) => {
    await dispatch(setCurrentActivityFromSequence(error.activity.custom.sequenceId));
    setTimeout(() => {
      switch (problem.type) {
        case DiagnosticTypes.INVALID_TARGET_INIT:
          dispatch(setCurrentRule({ currentRule: 'initState' }));
          break;
        case DiagnosticTypes.INVALID_TARGET_COND:
        case DiagnosticTypes.INVALID_VALUE:
          dispatch(setCurrentRule({ currentRule: problem.item.rule }));
          break;
        case DiagnosticTypes.INVALID_TARGET_MUTATE:
          dispatch(setCurrentRule({ currentRule: problem.item }));
          break;
      }
    }, 100);
  };

  const isRuleItem = (type: DiagnosticTypes) => DiagnosticRuleTypes.indexOf(type) > -1;

  return (
    <ListGroup>
      <ListGroup.Item>
        <ListGroup horizontal>
          <ListGroup.Item
            action
            onClick={() => handleClickScreen(error.activity.custom.sequenceId)}
          >
            {error.activity.custom.sequenceName}
          </ListGroup.Item>
          <ListGroup.Item>{errorTotals}</ListGroup.Item>
        </ListGroup>
      </ListGroup.Item>
      {error.problems.map((problem: any) => (
        <ListGroup.Item key={problem.owner.resourceId}>
          <ListGroup horizontal>
            <ListGroup.Item
              action={isRuleItem(problem.type)}
              className="flex-grow-1"
              onClick={() => handleProblemClick(problem)}
            >
              <DiagnosticMessage problem={problem} />
            </ListGroup.Item>
            {problem.type === DiagnosticTypes.DUPLICATE && (
              <ListGroup.Item
                action
                onClick={() => handleClickScreen(problem.owner.custom.sequenceId)}
              >
                {getOwnerName(problem)}
              </ListGroup.Item>
            )}
            {!isReadOnlyMode && (
              <ListGroup.Item>
                <DiagnosticSolution
                  type={problem.type}
                  suggestion={problem.suggestedFix}
                  onClick={(val: any) => handleProblemFix(val, problem)}
                />
              </ListGroup.Item>
            )}
          </ListGroup>
        </ListGroup.Item>
      ))}
    </ListGroup>
  );
};

interface DiagnosticsWindowProps {
  onClose?: () => void;
}

const DiagnosticsWindow: React.FC<DiagnosticsWindowProps> = ({ onClose }) => {
  const [results, setResults] = useState<any>(null);
  const dispatch = useDispatch();

  const handleClose = () => {
    if (onClose) {
      onClose();
    }
    dispatch(setShowDiagnosticsWindow({ show: false }));
  };

  const handleValidateClick = async () => {
    const result = await dispatch(validatePartIds({}));
    if ((result as any).meta.requestStatus === 'fulfilled') {
      if ((result as any).payload.errors.length > 0) {
        const errorList = (result as any).payload.errors.map((item: any) => {
          return (
            <ActivityPartError
              key={item.activity.resourceId}
              error={item}
              onApplyFix={() => setResults(null)}
            />
          );
        });
        setResults(errorList);
      } else {
        setResults(<p>No errors found.</p>);
      }
    }
  };

  return (
    <Fragment>
      <Modal
        show={true}
        size="xl"
        onHide={handleClose}
        dialogClassName="diagnostic-modal advanced-authoring"
      >
        <Modal.Header closeButton={true}>
          <h3 className="modal-title">Lesson Diagnostics</h3>
        </Modal.Header>
        <Modal.Body>
          <div className=" startup">
            <ul>
              <li>
                Validate Lesson
                <button className="btn btn-sm btn-primary ml-2" onClick={handleValidateClick}>
                  Execute
                </button>
              </li>
            </ul>
          </div>
          <hr />
          <div>{results}</div>
        </Modal.Body>
      </Modal>
    </Fragment>
  );
};

export default DiagnosticsWindow;
