import * as React from 'react';
import { Modal, ModalSize } from 'components/modal/Modal';

// eslint-disable-next-line
interface ModalMediaEditor {}

export interface ModalMediaEditorProps {
  onInsert: (model: any) => void;
  onCancel: () => void;
  model: any;
  editMode: boolean;
  projectSlug: string;
}

export interface ModalMediaEditorState {
  model: any;
}

class ModalMediaEditor extends React.PureComponent<ModalMediaEditorProps, ModalMediaEditorState> {
  constructor(props: ModalMediaEditorProps) {
    super(props);

    this.state = {
      model: props.model,
    };

    this.onEdit = this.onEdit.bind(this);
  }

  onEdit(model: any) {
    this.setState({ model });
  }

  renderChildren() {
    const additionalProps = {
      model: this.state.model,
      onEdit: this.onEdit,
    };
    return React.Children.map(this.props.children, (c) => {
      return React.cloneElement(c as any, additionalProps);
    });
  }

  render() {
    return (
      <Modal
        title="Edit"
        size={ModalSize.X_LARGE}
        okLabel="Done"
        cancelLabel="Cancel"
        onCancel={this.props.onCancel}
        onOk={() => this.props.onInsert(this.state.model)}
      >
        {this.renderChildren()}
      </Modal>
    );
  }
}

export default ModalMediaEditor;
