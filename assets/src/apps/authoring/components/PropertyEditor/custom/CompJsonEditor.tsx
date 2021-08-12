import { selectCurrentSelection } from 'apps/authoring/store/parts/slice';
import React, { CSSProperties, Fragment, useState } from 'react';
import { useEffect } from 'react';
import { Button, Modal } from 'react-bootstrap';
import { useSelector } from 'react-redux';
interface JsonEditorProps {
  jsonValue: any;
  onChange: (changedJson: any) => void;
  existingPartIds: string[];
}
const CompJsonEditor: React.FC<JsonEditorProps> = (props: any) => {
  const { jsonValue, onChange, existingPartIds } = props;
  const val = { id: jsonValue.id, custom: jsonValue.custom };
  const [value, setValue] = useState<string>(JSON.stringify(val, null, 4));
  const [validationMsg, setValidationMsg] = useState<string>('');
  const currentPartSelection = useSelector(selectCurrentSelection);
  const [displayEditor, setDisplayEditor] = useState<boolean>(false);
  const textAreaStyle: CSSProperties = {
    width: '100%',
  };
  useEffect(() => {
    try {
      const jsonVal = JSON.parse(value);
      if (existingPartIds.indexOf(jsonVal.id) !== -1 && currentPartSelection !== jsonVal.id) {
        document.getElementById('btnSave')?.setAttribute('disabled', 'disabled');
        setValidationMsg('ID you have used is already exist in the current Activity.');
      } else {
        setValidationMsg('');
        document.getElementById('btnSave')?.removeAttribute('disabled');
      }
    } catch (e) {
      document.getElementById('btnSave')?.setAttribute('disabled', 'disabled');
      setValidationMsg('Please make sure the JSON is in proper format.');
    }
  }, [value]);
  return (
    <Fragment>
      <Button onClick={() => setDisplayEditor(true)}>
        <i className="fas fa-edit mr-2" />
      </Button>
      <Modal show={displayEditor} onHide={() => setDisplayEditor(false)}>
          <Modal.Header closeButton={true}>
            <h4 className="modal-title">Edit JSON</h4>
          </Modal.Header>
          <Modal.Body>
            <textarea
              style={textAreaStyle}
              rows={20}
              onChange={(e) => {
                setValue(e.target.value);
              }}
            >
              {value}
            </textarea>
            <label className="text-danger">{validationMsg}</label>
          </Modal.Body>
          <Modal.Footer>
            <button
              id="btnSave"
              type="button"
              className="btn btn-success"
              onClick={() => {
                setDisplayEditor(false);
                onChange(JSON.parse(value))}}
            >
              Save
            </button>
            <button type="button" className="btn btn-danger" onClick={() => setDisplayEditor(false)}>
              Cancel
            </button>
          </Modal.Footer>
      </Modal>
    </Fragment>
  );
};

export default CompJsonEditor;
