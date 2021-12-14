import * as React from 'react';
import ModalSelection, { sizes } from 'components/modal/ModalSelection';
class ModalMediaEditor extends React.PureComponent {
    constructor(props) {
        super(props);
        this.state = {
            model: props.model,
        };
        this.onEdit = this.onEdit.bind(this);
    }
    onEdit(model) {
        this.setState({ model });
    }
    renderChildren() {
        const additionalProps = {
            model: this.state.model,
            onEdit: this.onEdit,
        };
        return React.Children.map(this.props.children, (c) => {
            return React.cloneElement(c, additionalProps);
        });
    }
    render() {
        return (<ModalSelection title="Edit" size={sizes.extraLarge} okLabel="Done" cancelLabel="Cancel" onCancel={this.props.onCancel} onInsert={() => this.props.onInsert(this.state.model)}>
        {this.renderChildren()}
      </ModalSelection>);
    }
}
export default ModalMediaEditor;
//# sourceMappingURL=ModalMediaEditor.jsx.map