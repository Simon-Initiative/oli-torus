import { selectCurrentSelection } from 'apps/authoring/store/parts/slice';
import React, { ChangeEvent, CSSProperties, Fragment, useState } from 'react';
import { useEffect } from 'react';
import { Button, Modal } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { transformModelToSchema } from '../schemas/part';
import Ajv from 'ajv';
interface JsonEditorProps {
  jsonValue: any;
  onChange: (changedJson: any) => void;
  schema: any;
  existingPartIds: string[];
}
const CompJsonEditor: React.FC<JsonEditorProps> = (props) => {
  const { jsonValue, onChange, existingPartIds, schema } = props;
  const [value, setValue] = useState<string>(JSON.stringify(jsonValue, null, 4));
  const [validationMsg, setValidationMsg] = useState<string>();
  const currentPartSelection = useSelector(selectCurrentSelection);
  const [displayEditor, setDisplayEditor] = useState<boolean>(false);
  const textAreaStyle: CSSProperties = {
    width: '100%',
  };
  useEffect(() => {
    setValue(JSON.stringify(jsonValue, null, 4));
  }, [jsonValue]);
  const addRequiredFields = (schema: any) => {
    schema.required = ['id', 'type'];
    schema.properties.custom.properties.palette.required = ['backgroundColor', 'borderColor'];
  };
  const handleOnChange = (event: ChangeEvent<HTMLTextAreaElement>) => {
    const changedVal = event.target.value;
    setValue(changedVal);
    try {
      const ajv = new Ajv();
      const valid = ajv.validate(schema, transformModelToSchema(JSON.parse(changedVal)));
      const jsonVal = JSON.parse(changedVal);
      if (existingPartIds.indexOf(jsonVal.id) !== -1 && currentPartSelection !== jsonVal.id) {
        setValidationMsg('ID you have used is already exist in the current Activity.');
      } else if (!jsonVal.id) {
        setValidationMsg('ID is required');
      } else if (!valid) {
        const errors = ajv.errors?.reduce((acc, error) => acc.concat(getErrorMsg(error)), '');
        setValidationMsg(errors);
      } else {
        setValidationMsg('');
      }
    } catch (e) {
      setValidationMsg('Please make sure the JSON is in proper format.');
    }
  };
  const getErrorMsg = (error: any) => {
    if (error) {
      return `${error.params.missingProperty} is required`;
    }
    return '';
  };
  addRequiredFields(schema);
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
          <textarea style={textAreaStyle} rows={20} onChange={handleOnChange} value={value} />
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
      </Modal>
    </Fragment>
  );
};

export default CompJsonEditor;
