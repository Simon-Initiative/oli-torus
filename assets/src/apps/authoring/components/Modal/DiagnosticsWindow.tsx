import { selectReadOnly, setShowDiagnosticsWindow } from 'apps/authoring/store/app/slice';
import { setCurrentActivityFromSequence } from 'apps/authoring/store/groups/layouts/deck/actions/setCurrentActivityFromSequence';
import { validatePartIds } from 'apps/authoring/store/groups/layouts/deck/actions/validate';
import { DiagnosticMessage } from './DiagnosticMessage';
import { DiagnosticTypes } from './DiagnosticTypes';

import { setCurrentSelection } from 'apps/authoring/store/parts/slice';
import React, { Fragment, useState } from 'react';
import { ListGroup, Modal } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { DiagnosticSolution } from './DiagnosticSolution';

const ActivityPartError: React.FC<{ error: any; onApplyFix: () => void }> = ({
  error,
  onApplyFix,
}) => {
  const dispatch = useDispatch();
  const isReadOnlyMode = useSelector(selectReadOnly);

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
    console.log(problem, fixed);

    await dispatch(setCurrentSelection(''));
    const result = await dispatch(problem.createUpdater(problem, fixed));

    console.log('handleProblemFix', result);

    // TODO: something if it fails
    onApplyFix();
  };

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
            <ListGroup.Item>
              <DiagnosticMessage problem={problem} />
            </ListGroup.Item>
            {problem.type === DiagnosticTypes.DUPLICATE && (
              <Fragment>
                <ListGroup.Item
                  action
                  onClick={() => handleClickScreen(problem.owner.custom.sequenceId)}
                >
                  {getOwnerName(problem)}
                </ListGroup.Item>
              </Fragment>
            )}
            {!isReadOnlyMode && (
              <ListGroup.Item>
                <DiagnosticSolution
                  problem={problem}
                  suggestion={problem.suggestedFix}
                  onClick={(val) => handleProblemFix(val, problem)}
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

  const handleValidatePartIdsClick = async () => {
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
      <Modal show={true} size="xl" onHide={handleClose}>
        <Modal.Header closeButton={true}>
          <h3 className="modal-title">Lesson Diagnostics</h3>
        </Modal.Header>
        <Modal.Body>
          <div>
            <ul>
              <li>
                Validate Part Ids <button onClick={handleValidatePartIdsClick}>Execute</button>
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
