/* eslint-disable @typescript-eslint/ban-types */
import React, { CSSProperties, ChangeEvent, Fragment, useState } from 'react';
import { useEffect } from 'react';
import { Button, Modal } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { selectCurrentSelection } from 'apps/authoring/store/parts/slice';
import { AdvancedAuthoringModal } from '../../AdvancedAuthoringModal';

interface JsonEditorProps {
  jsonValue: any;
  onChange: (changedJson: object) => void;
  existingPartIds: string[];
  onfocusHandler: (focus: boolean) => void;
}
const CompJsonEditor: React.FC<JsonEditorProps> = (props) => {
  const { jsonValue, onChange, existingPartIds, onfocusHandler } = props;
  let val = { id: jsonValue.id, custom: jsonValue.custom };
  const [value, setValue] = useState<string>(JSON.stringify(val, null, 4));
  const [validationMsg, setValidationMsg] = useState<string>('');
  const currentPartSelection = useSelector(selectCurrentSelection);
  const [displayEditor, setDisplayEditor] = useState<boolean>(false);
  const textAreaStyle: CSSProperties = {
    width: '100%',
  };
  useEffect(() => {
    val = { id: jsonValue.id, custom: jsonValue.custom };
    setValue(JSON.stringify(val, null, 4));
  }, [jsonValue]);

  const handleOnChange = (event: ChangeEvent<HTMLTextAreaElement>) => {
    const changedVal = event.target.value;
    setValue(changedVal);
    try {
      const jsonVal = JSON.parse(changedVal);
      if (existingPartIds.indexOf(jsonVal.id) !== -1 && currentPartSelection !== jsonVal.id) {
        setValidationMsg('ID you have used is already exist in the current Activity.');
      } else if (!jsonVal.id) {
        setValidationMsg('ID is required and cannot be empty.');
      } else {
        setValidationMsg('');
      }
    } catch (e) {
      setValidationMsg('Please make sure the JSON is in proper format.');
    }
  };
  return (
    <Fragment>
      <Button onClick={() => setDisplayEditor(true)}>
        <i className="fas fa-edit mr-2" />
      </Button>
      <AdvancedAuthoringModal show={displayEditor} onHide={() => setDisplayEditor(false)}>
        <Modal.Header closeButton={true}>
          <h4 className="modal-title">Edit JSON</h4>
        </Modal.Header>
        <Modal.Body>
          <textarea
            onFocus={() => onfocusHandler(false)}
            style={textAreaStyle}
            rows={20}
            onChange={handleOnChange}
            value={value}
            onBlur={() => onfocusHandler(true)}
          />
          <label className="text-danger">{validationMsg}</label>
        </Modal.Body>
        <Modal.Footer>
          <button
            id="btnSave"
            type="button"
            className="btn btn-success"
            onClick={() => {
              setDisplayEditor(false);
              onChange(JSON.parse(value));
            }}
            disabled={validationMsg !== ''}
          >
            Save
          </button>
          <button type="button" className="btn btn-danger" onClick={() => setDisplayEditor(false)}>
            Cancel
          </button>
        </Modal.Footer>
      </AdvancedAuthoringModal>
    </Fragment>
  );
};

export default CompJsonEditor;
