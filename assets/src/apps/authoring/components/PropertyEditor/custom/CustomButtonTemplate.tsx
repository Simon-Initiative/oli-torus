import React, { CSSProperties, useRef, useState } from 'react';
interface CustomButtonProps {
  label: string;
  onChange: any;
}
const CustomButtonTemplate: React.FC<CustomButtonProps> = (props: any) => {
  const [displayJsonEditor, setDisplayJsonEditor] = useState(false);
  const editorRef = useRef<HTMLDivElement>(null);

  const handleButtonClick = () => {
    setDisplayJsonEditor(true);
    document.addEventListener('mousedown', handleClick);
  };
  const handleClick = (event: any) => {
    if (editorRef.current && !editorRef.current.contains(event.target)) {
      setDisplayJsonEditor(false);
      document.removeEventListener('mousedown', handleClick);
    }
  };

  const popup: CSSProperties = {
    position: 'fixed',
    width: '50%',
    height: '50%',
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
  return (
    <div className="d-flex justify-content-center">
      <button className="form-button" onClick={handleButtonClick}>
        {props.label}
      </button>
      {displayJsonEditor ? (
        <div style={popup} ref={editorRef} draggable="true">
          {props.label} <br />
          <textarea
            style={textAreaStyle}
            rows={19}
            onChange={(e) => {
              const json = JSON.parse(e.target.value);
              json.jsonChanged = true;
              props.onChange(JSON.stringify(json));
            }}
          >
            {props.value}
          </textarea>
        </div>
      ) : null}
    </div>
  );
};

export default CustomButtonTemplate;
