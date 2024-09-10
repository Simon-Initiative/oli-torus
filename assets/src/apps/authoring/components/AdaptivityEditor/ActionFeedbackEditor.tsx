import React, { useCallback, useEffect, useState } from 'react';
import { Modal, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch } from 'react-redux';
import ScreenAuthor from 'components/activities/adaptive/components/authoring/ScreenAuthor';
import { setCurrentPartPropertyFocus } from 'apps/authoring/store/parts/slice';
import { FeedbackAction } from 'apps/authoring/types';
import guid from 'utils/guid';
import { AdvancedAuthoringModal } from '../AdvancedAuthoringModal';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';

interface ActionFeedbackEditorProps {
  action: FeedbackAction;
  onChange: (changes: any) => void;
  onDelete: (changes: FeedbackAction) => void;
}

const ActionFeedbackEditor: React.FC<ActionFeedbackEditorProps> = ({
  action,
  onDelete,
  onChange,
}) => {
  const [fakeFeedback, setFakeFeedback] = useState<string>('');
  const uuid = guid();
  const dispatch = useDispatch();
  const [feedback, setFeedback] = useState<any>(action.params?.feedback || {});
  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);

  useEffect(() => {
    setFeedback(action.params?.feedback || {});
  }, [action.params]);

  useEffect(() => {
    feedback.partsLayout?.forEach((part: any) =>
      part.custom?.nodes?.forEach((node: any) => {
        const feedbackText = getFeedbackTextFromNode(node);
        setFakeFeedback(feedbackText);
      }),
    );
  }, [feedback]);

  const getFeedbackTextFromNode = (node: any): any => {
    let nodeText = '';
    if (node?.tag === 'text') {
      nodeText = node.text;
    } else if (node?.children?.length > 0) {
      nodeText = getFeedbackTextFromNode(node?.children[0]);
    } else {
      nodeText = 'unknown';
    }
    return nodeText;
  };

  const [showEditor, setShowEditor] = useState(false);

  const handleShowFeedbackClick = () => {
    setShowEditor(true);
  };

  const handleCancelEdit = useCallback(() => {
    // TODO: this revert causes infinite loop
    // setFeedback(action.params?.feedback || {});
    setShowEditor(false);
    dispatch(setCurrentPartPropertyFocus({ focus: true }));
  }, [feedback]);

  const handleSaveEdit = useCallback(() => {
    setShowEditor(false);
    onChange({ feedback });
    dispatch(setCurrentPartPropertyFocus({ focus: true }));
  }, [feedback]);

  const handleScreenAuthorChange = (screen: any) => {
    // console.log('ActionFeedbackEditor Screen Author Change', { screen });
    setFeedback(screen);
  };

  return (
    <div className="aa-action d-flex mb-2 form-inline align-items-center flex-nowrap flex-row">
      <label className="sr-only" htmlFor={`action-feedback-${uuid}`}>
        show feedback
      </label>
      <div className="input-group input-group-sm flex-grow-1 flex-row flex-nowrap">
        <div className="input-group-prepend">
          <div
            className="input-group-text"
            onClick={handleShowFeedbackClick}
            style={{ cursor: 'pointer' }}
          >
            <i className="fa fa-comment mr-1" />
            Show Feedback
          </div>
        </div>
        <input
          type="text"
          className="form-control form-control-sm"
          id={`action-feedback-${uuid}`}
          placeholder="Enter feedback"
          disabled={false}
          readOnly={true}
          onClick={handleShowFeedbackClick}
          onFocus={(e) => dispatch(setCurrentPartPropertyFocus({ focus: false }))}
          defaultValue={fakeFeedback}
          // onChange={(e) => setFakeFeedback(e.target.value)}
          // onBlur={(e) => handleTargetChange(e)}
          title={fakeFeedback}
        />
      </div>
      <OverlayTrigger
        placement="top"
        delay={{ show: 150, hide: 150 }}
        overlay={
          <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
            Delete Action
          </Tooltip>
        }
      >
        <span>
          <button className="btn btn-link p-0 ml-1" onClick={() => setShowConfirmDelete(true)}>
            <i className="fa fa-trash-alt" />
          </button>
        </span>
      </OverlayTrigger>
      <AdvancedAuthoringModal
        dialogClassName="modal-90w"
        show={showEditor}
        onHide={handleCancelEdit}
      >
        <Modal.Header closeButton={true}>
          <h3 className="modal-title">Feedback</h3>
        </Modal.Header>
        <Modal.Body>
          <ScreenAuthor screen={feedback} onChange={handleScreenAuthorChange} />
        </Modal.Body>
        <Modal.Footer>
          <button className="btn btn-secondary" onClick={handleCancelEdit}>
            Cancel
          </button>
          <button className="btn btn-danger" onClick={handleSaveEdit}>
            Save
          </button>
        </Modal.Footer>
      </AdvancedAuthoringModal>
      {showConfirmDelete && (
        <ConfirmDelete
          show={showConfirmDelete}
          elementType="Action"
          elementName="this feedback action"
          deleteHandler={() => {
            onDelete(action);
            setShowConfirmDelete(false);
          }}
          cancelHandler={() => {
            setShowConfirmDelete(false);
          }}
        />
      )}
    </div>
  );
};

export default ActionFeedbackEditor;
