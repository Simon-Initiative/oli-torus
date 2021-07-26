import * as React from 'react';

export interface TextInputProps {
  style?: any;
  editMode: boolean;
  width?: string;
  label: string;
  value: string;
  type: string;
  onEdit: (value: string) => void;
  hasError?: boolean;
}

export class TextInput extends React.PureComponent<TextInputProps, Record<string, never>> {

  constructor(props: TextInputProps) {
    super(props);

    this.onChange = this.onChange.bind(this);
  }

  onChange(e: any) {
    const value = e.target.value;
    const { onEdit } = this.props;

    onEdit(value);
  }

  render() {
    return (
      <input
        disabled={!this.props.editMode}
        style={Object.assign((this.props.style || {}), { width: this.props.width })}
        placeholder={this.props.label}
        onChange={this.onChange}
        className={`form-control form-control-sm ${this.props.hasError ? 'is-invalid' : ''}`}
        type={this.props.type}
        value={this.props.value} />
    );
  }
}
