import { RichTextEditor } from 'components/content/RichTextEditor';
import { FullScreenModal } from 'components/editing/toolbars/FullScreenModal';
import React from 'react';
export const PopupContentModal = (props) => {
    const [content, setContent] = React.useState(props.model.content);
    const [trigger, setTrigger] = React.useState(props.model.trigger);
    const isTriggerMode = (mode) => mode === trigger;
    const triggerSettings = (<form onSubmit={() => { }} id="popup__trigger_mode">
      <div className="form-check form-switch">
        <div className="form-group">
          <label className="form-check-label">
            <input type="radio" className="form-check-input" onChange={() => setTrigger('hover')} checked={isTriggerMode('hover')}/>
            <p>
              Trigger on <b>mouseover</b>
            </p>
          </label>
        </div>
        <div className="form-group">
          <label className="form-check-label">
            <input type="radio" className="form-check-input" onChange={() => setTrigger('click')} checked={isTriggerMode('click')}/>
            <p>
              Trigger on <b>click</b>
            </p>
          </label>
        </div>
      </div>
    </form>);
    return (<FullScreenModal onCancel={(_e) => props.onCancel()} onDone={(_e) => props.onDone({ content, trigger })}>
      <div className="row">
        <div className="col-12">
          <h3 className="mb-2">Popup Content</h3>
          <p className="mb-4">Shown to students when triggered</p>
          <div className="popup__modalContent">
            {triggerSettings}
            <RichTextEditor preventLargeContent editMode={true} projectSlug={props.commandContext.projectSlug} value={content} onEdit={(content) => setContent(content)}/>
          </div>
        </div>
      </div>
    </FullScreenModal>);
};
//# sourceMappingURL=PopupContentModal.jsx.map