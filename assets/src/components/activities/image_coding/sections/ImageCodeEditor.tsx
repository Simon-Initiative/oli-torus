import React from 'react';
import AceEditor from 'react-ace';
import 'ace-builds/src-noconflict/mode-javascript';
import 'ace-builds/src-noconflict/theme-xcode';

export type ImageCodeEditorProps = {
  value: string;
  onChange: (newValue: string) => void;
  disabled: boolean;
};

export const ImageCodeEditor = (props: ImageCodeEditorProps) => {
  const value = props.value === null ? '' : props.value;
  // style edit box border to match other input controls
  const styles: React.CSSProperties = {
    border: '1px solid rgb(212,212,212)',
    borderRadius: '0.375rem',
  };
  if (props.disabled) styles.background = '#ECF0F1';

  return (
    <AceEditor
      className="form-control"
      mode="javascript"
      theme="xcode"
      minLines={7}
      maxLines={40}
      width="parent"
      value={value}
      onChange={props.onChange}
      readOnly={props.disabled}
      style={styles}
      setOptions={{
        showLineNumbers: false,
        tabSize: 4,
        showGutter: false,
        highlightActiveLine: false,
        fontSize: 14,
        useWorker: false, // background worker script causes problems
      }}
    />
  );
};
