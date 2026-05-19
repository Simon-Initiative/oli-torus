export type MessageEditorComponent = React.FC<{
  onChange: (newVal: string) => void;
  value: string;
}> & { label: string };

export interface CommandTarget {
  id: string;
  componentType: string;
  label: string;
  MessageEditor?: MessageEditorComponent;
}
