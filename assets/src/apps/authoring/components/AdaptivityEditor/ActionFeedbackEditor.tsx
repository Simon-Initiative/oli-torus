import React, { Fragment, useState } from 'react';
// import { Button, Icon, List, Modal } from 'semantic-ui-react';
// import ContentService from '../../../services/ContentService';
// import JsonEditor from '../../JsonEditor/JsonEditor';

const ActionFeedbackEditor = (props: any) => {
  // const textFlowSchema:any = ContentService.getInstance().getComponentSchema('janus-text-flow');
  const { action } = props;

  const [open, setOpen] = useState(false);

  const [textData, setTextData] = useState<any>({});

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
    <div>ActionFeedbackEditor coming soon</div>
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
