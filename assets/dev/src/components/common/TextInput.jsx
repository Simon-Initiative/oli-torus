import * as React from 'react';
export class TextInput extends React.PureComponent {
    constructor(props) {
        super(props);
        this.onChange = this.onChange.bind(this);
    }
    onChange(e) {
        const value = e.target.value;
        const { onEdit } = this.props;
        onEdit(value);
    }
    render() {
        return (<input disabled={!this.props.editMode} style={Object.assign(this.props.style || {}, { width: this.props.width })} placeholder={this.props.label} onChange={this.onChange} className={`form-control ${this.props.hasError ? 'is-invalid' : ''}`} type={this.props.type} value={this.props.value}/>);
    }
}
//# sourceMappingURL=TextInput.jsx.map