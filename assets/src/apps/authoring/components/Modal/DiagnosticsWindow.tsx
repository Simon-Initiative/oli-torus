import { setShowDiagnosticsWindow } from 'apps/authoring/store/app/slice';
import { setCurrentActivityFromSequence } from 'apps/authoring/store/groups/layouts/deck/actions/setCurrentActivityFromSequence';
import { validatePartIds } from 'apps/authoring/store/groups/layouts/deck/actions/validate';
import React, { Fragment, useState } from 'react';
import { ListGroup, Modal } from 'react-bootstrap';
import { useDispatch } from 'react-redux';

const ActivityPartError: React.FC<{ error: any }> = ({ error }) => {
  const dispatch = useDispatch();

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
          return <ActivityPartError key={item.activity.resourceId} error={item} />;
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
