import * as React from 'react';

interface ModalSelection {
  modal: any;
}

export enum sizes {
  small = 'sm',
  medium = 'md',
  large = 'lg',
  extraLarge = 'xlg',
}

export interface ModalSelectionProps {
  okLabel?: string;
  okClassName?: string;
  cancelLabel?: string;
  disableInsert?: boolean;
  title: string;
  onInsert: () => void;
  onCancel: () => void;
  size?: sizes;
}

class ModalSelection extends React.PureComponent<ModalSelectionProps, {}> {

  componentDidMount() {
    (window as any).$(this.modal).modal('show');
  }

  componentWillUnmount() {
    (window as any).$(this.modal).modal('hide');
  }

  onInsert = (e: any) => { e.preventDefault(); this.props.onInsert(); };

  onCancel = (e: any) => { e.preventDefault(); this.props.onCancel(); };

  render() {
    const disableInsert = this.props.disableInsert;
    const okLabel = this.props.okLabel !== undefined
      ? this.props.okLabel : 'Insert';
    const cancelLabel = this.props.cancelLabel !== undefined
      ? this.props.cancelLabel : 'Cancel';
    const okClassName = this.props.okClassName !== undefined
      ? this.props.okClassName : 'primary';
    const size = this.props.size || 'lg';

    return (
      <div ref={(modal) => { this.modal = modal; }}
        data-backdrop="true" className="modal">
        <div className={`modal-dialog modal-dialog-centered modal-${size}`} role="document">
          <div className="modal-content">
            <div className="modal-header">
              <h5 className="modal-title">{this.props.title}</h5>
              <button
                type="button"
                className="close"
                onClick={this.onCancel}>
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div className="modal-body">
              {this.props.children}
            </div>
            <div className="modal-footer">
              <button
                disabled={disableInsert}
                type="button"
                onClick={this.onInsert}
                className={`btn btn-${okClassName}`}>{okLabel}</button>
              <button type="button" className="btn btn-link"
                onClick={this.onCancel}
                data-dismiss="modal">{cancelLabel}</button>
            </div>
          </div>
        </div>
      </div>
    );
  }
}

export default ModalSelection;
