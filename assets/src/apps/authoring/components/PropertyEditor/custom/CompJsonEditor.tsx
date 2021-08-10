import React, { CSSProperties, useState } from 'react';
interface JsonEditoProps {
  jsonValue: any;
  onChangeHandler: any;
}
const CompJsonEditor: React.FC<JsonEditoProps> = (props: any) => {
  const { jsonValue, onChangeHandler } = props;
  const val = { id: jsonValue.id, custom: jsonValue.custom };
  const [value, setValue] = useState<string>(JSON.stringify(val, null, 4));
  const popup: CSSProperties = {
    position: 'fixed',
    width: '50%',
    height: '60%',
    top: '20px',
    inset: 0,
    margin: 'auto',
    border: '1px solid grey',
    background: 'white',
    padding: '10px',
    zIndex: 202,
    boxShadow: '0 10px 8px 0 , 0 10px 20px 0 ',
  };
  const textAreaStyle: CSSProperties = {
    width: '100%',
  };
  const buttonStyle: CSSProperties = {
    width: '100px',
  };
  return (
    <div style={popup}>
      <h4>Edit JSON</h4>
      <textarea
        style={textAreaStyle}
        rows={20}
        onChange={(e) => {
          setValue(e.target.value);
        }}
      >
        {value}
      </textarea>
      <div className="d-flex justify-content-end">
        <button
          style={buttonStyle}
          className="form-control"
          onClick={() => onChangeHandler(JSON.parse(value))}
        >
          Save
        </button>
        <button
          style={buttonStyle}
          className="form-control"
          onClick={() => onChangeHandler({}, true)}
        >
          Cancel
        </button>
      </div>
    </div>
  );
};

export default CompJsonEditor;
