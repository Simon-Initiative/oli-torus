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
  hideDialogCloseButton?: boolean;
  title: string;
  hideOkButton?: boolean;
  onInsert: () => void;
  onCancel: () => void;
  size?: sizes;
}

interface ModalSelectionState {
  disableInsert: boolean;
}

class ModalSelection extends React.PureComponent<ModalSelectionProps, ModalSelectionState> {

  state = {
    disableInsert: this.props.disableInsert === undefined ? false : this.props.disableInsert,
  };

  componentDidMount() {
    (window as any).$(this.modal).modal('show');
  }

  componentWillUnmount() {
    (window as any).$(this.modal).modal('hide');
  }

  onInsert = (e: any) => { e.preventDefault(); this.props.onInsert(); };

  onCancel = (e: any) => { e.preventDefault(); this.props.onCancel(); };

  render() {
    const disableInsert = this.state.disableInsert;
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
              {this.props.hideDialogCloseButton === true
              ? null
              :
              <button
                type="button"
                className="close"
                onClick={this.onCancel}>
                <span aria-hidden="true">&times;</span>
              </button>}
            </div>
            <div className="modal-body">
              {React.Children.map(this.props.children, child =>
                React.cloneElement(child as React.ReactElement<any>, {
                  toggleDisableInsert: (bool: boolean) => this.setState({ disableInsert: bool }),
                }))}
            </div>
            <div className="modal-footer">
              <button type="button" className="btn btn-link"
                onClick={this.onCancel}
                data-dismiss="modal">{cancelLabel}</button>
              {this.props.hideOkButton === true
                ? null
                : <button
                  disabled={disableInsert}
                  type="button"
                  onClick={this.onInsert}
                  className={`btn btn-${okClassName}`}>{okLabel}</button>}
            </div>
          </div>
        </div>
      </div>
    );
  }
}

export default ModalSelection;
