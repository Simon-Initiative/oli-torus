import React, { CSSProperties, useRef, useState } from 'react';
import { JsonEditor as Editor } from 'jsoneditor-react';
interface CustomButtonProps {
  label: string;
}
const CustomButtonTemplate: React.FC<CustomButtonProps> = (props: any) => {
  const jsonValue = props.value;
  const [displayJsonEditor, setDisplayJsonEditor] = useState(false);
  const pickerRef = useRef<HTMLDivElement>(null);

  const handleButtonClick = () => {
    setDisplayJsonEditor(true);
  };
  const handleClick = () => {
    setDisplayJsonEditor(false);
  };
  const popup: CSSProperties = {
    position: 'absolute',
    width: '50%',
    top: '20px',
    inset: 0,
    margin: 'auto',
    border: '1px solid grey',
    background: 'white',
  };
  const cover: CSSProperties = {
    position: 'fixed',
    background: 'black',
    opacity: 0.8,
    top: '0px',
    right: '0px',
    bottom: '0px',
    left: '0px',
    zIndex: 202,
  };
  return (
    <div className="d-flex justify-content-center">
      <button className="form-button" onClick={handleButtonClick}>
        {props.title}
      </button>
      {displayJsonEditor ? (
        <div style={cover} onClick={handleClick}>
          <div style={popup} ref={pickerRef}>
            <JSONInput />
          </div>
        </div>
      ) : null}
    </div>
  );
};

export default CustomButtonTemplate;
