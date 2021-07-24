import React, { useEffect, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import guid from 'utils/guid';

const ActionFeedbackEditor = (props: any) => {
  // const textFlowSchema:any = ContentService.getInstance().getComponentSchema('janus-text-flow');
  const { action } = props;
  const [open, setOpen] = useState(false);
  const [textData, setTextData] = useState<any>({});
  const [fakeFeedback, setFakeFeedback] = useState<string>('');
  const uuid = guid();

  useEffect(() => {
    action.params?.feedback?.partsLayout?.forEach((part: any) =>
      part.custom?.nodes?.forEach((node: any) => {
        const feedbackText = getFeedbackTextFromNode(node);
        setFakeFeedback(feedbackText);
      }),
    );
  }, []);

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

  // const handleOpenModal = async () => {
  //   const feedbackEnsemble = await ContentService.getInstance().getEnsembleById(
  //     action.params.idref,
  //   );
  //   if (!feedbackEnsemble) {
  //     console.error('couldnt find ensemble!', action.params.idref);
  //     return;
  //   }
  //   // for now we'll assume feedback *only* has a single text entry
  //   if (feedbackEnsemble.activityRefs.length !== 1) {
  //     console.warn('feedback ensemble is not how we expect', {
  //       feedbackEnsemble,
  //     });
  //   }
  //   const tfActivity:any= await ContentService.getInstance().getActivityById(
  //     feedbackEnsemble.activityRefs[0].idref,
  //   );
  //   if (tfActivity?.type !== 'janus-text-flow') {
  //     console.error('first activity isnt a text flow!', { tfActivity });
  //     return;
  //   }
  //   if (tfActivity) {
  //     setTextData(tfActivity);
  //   }
  //   setOpen(true);
  // };

  // const handleFeedbackEdit = (editor:any) => {
  //   console.log('edit feedback text', { action, editor });
  //   editor.getEditor('root.id')?.disable();
  //   editor.getEditor('root.type')?.disable();

  //   editor.on('change', () => {
  //     const value = editor.getValue();
  //     console.log('FEEDBACK: ACTIVITY EDITOR CHANGE', {
  //       value,
  //     });
  //     if (!value || !value.id) {
  //       return;
  //     }
  //     ContentService.getInstance().updateActivity(value);
  //   });
  // };

  return (
    <div className="aa-action d-flex mb-2 form-inline align-items-center flex-nowrap">
      <label className="sr-only" htmlFor={`action-feedback-${uuid}`}>
        show feedback
      </label>
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend">
          <div className="input-group-text">
            <i className="fa fa-comment mr-1" />
            Show feedback
          </div>
        </div>
        <input
          type="text"
          className="form-control form-control-sm"
          id={`action-feedback-${uuid}`}
          placeholder="Enter feedback"
          value={fakeFeedback}
          onChange={(e) => setFakeFeedback(e.target.value)}
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
          <button className="btn btn-link p-0 ml-1">
            <i className="fa fa-trash-alt" />
          </button>
        </span>
      </OverlayTrigger>
    </div>
    // <Fragment>
    //   <Icon name="comment" size="large" />
    //   <List.Content>
    //     Show Feedback:{' '}
    //     <Modal
    //       onClose={() => setOpen(false)}
    //       onOpen={handleOpenModal}
    //       open={open}
    //       trigger={<Button>Edit</Button>}
    //     >
    //       <Modal.Header>Edit Feedback</Modal.Header>
    //       <Modal.Content>
    //         <Modal.Description>
    //           <p>Edit teh textflow here</p>
    //         </Modal.Description>
    //         {open ? (
    //           <JsonEditor
    //             schema={textFlowSchema}
    //             item={textData}
    //             onEditorReady={handleFeedbackEdit}
    //           />
    //         ) : null}
    //       </Modal.Content>
    //       <Modal.Actions>
    //         <Button color="black" onClick={() => setOpen(false)}>
    //           Done
    //         </Button>
    //       </Modal.Actions>
    //     </Modal>
    //     <sub>{action.params.idref}</sub>
    //   </List.Content>
    // </Fragment>
  );
};

export default ActionFeedbackEditor;
