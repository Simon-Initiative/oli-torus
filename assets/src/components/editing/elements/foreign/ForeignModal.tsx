import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { Modal, ModalSize } from 'components/modal/Modal';
import * as ContentModel from 'data/content/model/elements/types';
import React, { useCallback } from 'react';

interface Props {
  onDone: (changes: Partial<ContentModel.Foreign>) => void;
  onCancel: () => void;
  model: ContentModel.Foreign;
  commandContext: CommandContext;
}
export const ForeignModal = (props: Props) => {
  const [lang, setLang] = React.useState(props.model.lang || '');
  const onLangChange = useCallback((e) => {
    setLang(e.target.value);
  }, []);

  return (
    <Modal
      title="Foreign Language Settings"
      okLabel="Save"
      cancelLabel="Cancel"
      size={ModalSize.LARGE}
      onCancel={() => props.onCancel()}
      onOk={() => props.onDone({ lang })}
    >
      <div className="row">
        <div className="col-12">
          <p className="mb-4">
            Set this text as belonging to a foreign language for screen readers to pronounce
            properly. This has no visual effect for the learner. You can set a project-wide default
            in your project settings.
          </p>
          <div className="popup__modalContent">
            <form onSubmit={() => {}} id="popup__trigger_mode">
              <div className="form-group">
                <label>Target Language</label>
                <input type="text" className="form-control" onChange={onLangChange} value={lang} />
              </div>
            </form>
          </div>
        </div>
      </div>
    </Modal>
  );
};
