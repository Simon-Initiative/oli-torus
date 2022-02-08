import React from 'react';
import AceEditor from 'react-ace';
import 'ace-builds/src-noconflict/mode-javascript';
import 'ace-builds/src-noconflict/theme-xcode';

export type XmlEditorProps = {
  value: string;
  onChange: (newValue: string) => void;
  disabled: boolean;
};

export const XmlEditor = (props: XmlEditorProps) => {
  const value = props.value === null ? '' : props.value;
  return (
    <AceEditor
      className="form-control"
      mode="xml"
      theme="xcode"
      minLines={7}
      maxLines={40}
      width="parent"
      value={value}
      onChange={props.onChange}
      readOnly={props.disabled}
      style={props.disabled ? { background: '#ECF0F1' } : {}}
      setOptions={{
        showLineNumbers: false,
        showGutter: false,
        highlightActiveLine: false,
        fontSize: 14,
        useWorker: false, // background worker script causes problems
      }}
    />
  );
};
