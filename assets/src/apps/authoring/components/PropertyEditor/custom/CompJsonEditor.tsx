import { selectCurrentSelection } from 'apps/authoring/store/parts/slice';
import React, { CSSProperties, useState } from 'react';
import { useEffect } from 'react';
import { useSelector } from 'react-redux';
interface JsonEditorProps {
  jsonValue: any;
  onChange: (changedJson: any) => void;
  onCancel: () => void;
  existingPartIds: string [];
}
const CompJsonEditor: React.FC<JsonEditorProps> = (props: any) => {
  const { jsonValue, onChange, onCancel, existingPartIds } = props;
  const val = { id: jsonValue.id, custom: jsonValue.custom };
  const [value, setValue] = useState<string>(JSON.stringify(val, null, 4));
  const [validationMsg, setValidationMsg] = useState<string>("");
  const currentPartSelection = useSelector(selectCurrentSelection);
  const textAreaStyle: CSSProperties = {
    width: '100%',
  };
  useEffect(() => {
    try {
      const jsonVal = JSON.parse(value);
      if(existingPartIds.indexOf(jsonVal.id) !== -1 && currentPartSelection !== jsonVal.id){
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
    <div className="modal show" id="jsonEditorModal">
      <div className="modal-dialog modal-dialog-centered">
        <div className="modal-content">
          <div className="modal-header">
            <h4 className="modal-title">Edit JSON</h4>
            <button type="button" className="close" data-dismiss="modal">
              &times;
            </button>
          </div>
          <div className="modal-body">
            <textarea
              style={textAreaStyle}
              rows={20}
              onChange={(e) => {
                setValue(e.target.value);
              }}
            >
              {value}
            </textarea>
            <label className='text-danger'>{validationMsg}</label>
          </div>
          <div className="modal-footer">
            <button
              id="btnSave"
              type="button"
              className="btn btn-success"
              onClick={() => onChange(JSON.parse(value))}
            >
              Save
            </button>
            <button
              type="button"
              className="btn btn-danger"
              onClick={() => onCancel()}
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CompJsonEditor;
