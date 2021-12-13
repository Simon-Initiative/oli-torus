import { selectReadOnly, setShowDiagnosticsWindow } from 'apps/authoring/store/app/slice';
import { setCurrentActivityFromSequence } from 'apps/authoring/store/groups/layouts/deck/actions/setCurrentActivityFromSequence';
import { validatePartIds } from 'apps/authoring/store/groups/layouts/deck/actions/validate';
import { updatePart } from 'apps/authoring/store/parts/actions/updatePart';
import { setCurrentSelection } from 'apps/authoring/store/parts/slice';
import React, { Fragment, useState } from 'react';
import { ListGroup, Modal } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';

const FixIdButton: React.FC<{ suggestion: string; onClick: (val: string) => void }> = ({
  suggestion,
  onClick,
}) => {
  const txtRef = React.useRef<HTMLInputElement>(null);

  const handleClick = () => {
    if (txtRef.current) {
      const newVal = txtRef.current.value;
      onClick(newVal);
    }
  };

  return (
    <>
      <input ref={txtRef} type="text" defaultValue={suggestion} />
      <button className="btn btn-sm btn-primary" onClick={handleClick}>
        Apply
      </button>
    </>
  );
};

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
  if (error.duplicates.length) {
    errorTotals += `${error.duplicates.length} components with duplicate IDs found.\n`;
  }
  if (error.problems.length) {
    errorTotals += `${error.problems.length} components with problematic IDs found.\n`;
  }

  const handleProblemFix = async (problem: any, fixed: string) => {
    /* console.log('fixing', problem, fixed); */
    const activityId = problem.owner.resourceId;
    const partId = problem.id;
    const changes = { id: fixed };

    await dispatch(setCurrentSelection(''));
    const result = await dispatch(updatePart({ activityId, partId, changes }));

    /* console.log('handleProblemFix', result); */

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
      {error.duplicates.map((duplicate: any) => (
        <ListGroup.Item key={duplicate.owner.resourceId}>
          <ListGroup horizontal>
            <ListGroup.Item>
              A {duplicate.type} component with the ID &quot;<strong>{duplicate.id}</strong>&quot;
              located on
            </ListGroup.Item>
            <ListGroup.Item
              action
              onClick={() => handleClickScreen(duplicate.owner.custom.sequenceId)}
            >
              {getOwnerName(duplicate)}
            </ListGroup.Item>
            {!isReadOnlyMode && (
              <ListGroup.Item>
                <FixIdButton
                  suggestion={duplicate.suggestedFix}
                  onClick={(val) => handleProblemFix(duplicate, val)}
                />
              </ListGroup.Item>
            )}
          </ListGroup>
        </ListGroup.Item>
      ))}
      {error.problems.map((problem: any) => (
        <ListGroup.Item key={problem.owner.resourceId}>
          <ListGroup horizontal>
            <ListGroup.Item>
              A {problem.type} component with the ID &quot;<strong>{problem.id}</strong>&quot;, has
              problematic characters. It is best to use alphanumeric characters only.
            </ListGroup.Item>
            {!isReadOnlyMode && (
              <ListGroup.Item>
                <FixIdButton
                  suggestion={problem.suggestedFix}
                  onClick={(val) => handleProblemFix(problem, val)}
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
