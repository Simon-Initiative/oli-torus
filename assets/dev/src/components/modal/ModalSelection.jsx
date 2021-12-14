import * as React from 'react';
export var sizes;
(function (sizes) {
    sizes["small"] = "sm";
    sizes["medium"] = "md";
    sizes["large"] = "lg";
    sizes["extraLarge"] = "xlg";
})(sizes || (sizes = {}));
class ModalSelection extends React.PureComponent {
    constructor() {
        super(...arguments);
        this.state = {
            disableInsert: this.props.disableInsert === undefined ? false : this.props.disableInsert,
        };
        this.onInsert = (e) => {
            e.preventDefault();
            if (this.props.onInsert)
                this.props.onInsert();
        };
        this.onCancel = (e) => {
            e.preventDefault();
            if (this.props.onCancel)
                this.props.onCancel();
        };
    }
    componentDidMount() {
        window.$(this.modal).modal('show');
    }
    componentWillUnmount() {
        window.$(this.modal).modal('hide');
    }
    render() {
        const disableInsert = this.state.disableInsert;
        const okLabel = this.props.okLabel !== undefined ? this.props.okLabel : 'Insert';
        const cancelLabel = this.props.cancelLabel !== undefined ? this.props.cancelLabel : 'Cancel';
        const okClassName = this.props.okClassName !== undefined ? this.props.okClassName : 'primary';
        const size = this.props.size || 'lg';
        return (<div ref={(modal) => {
                this.modal = modal;
            }} data-backdrop="true" className="modal">
        <div className={`modal-dialog modal-dialog-centered modal-${size}`} role="document">
          <div className="modal-content">
            <div className="modal-header">
              <h5 className="modal-title">{this.props.title}</h5>
              {this.props.hideDialogCloseButton === true ? null : (<button type="button" className="close" onClick={this.onCancel} data-dismiss="modal">
                  <span aria-hidden="true">&times;</span>
                </button>)}
            </div>
            <div className="modal-body">
              {React.Children.map(this.props.children, (child) => React.cloneElement(child, {
                toggleDisableInsert: (bool) => this.setState({ disableInsert: bool }),
            }))}
            </div>
            <div className="modal-footer">
              {this.props.footer ? (this.props.footer) : (<>
                  <button type="button" className="btn btn-link" onClick={this.onCancel} data-dismiss="modal">
                    {cancelLabel}
                  </button>
                  {this.props.hideOkButton === true ? null : (<button disabled={disableInsert} type="button" onClick={this.onInsert} className={`btn btn-${okClassName}`}>
                      {okLabel}
                    </button>)}
                </>)}
            </div>
          </div>
        </div>
      </div>);
    }
}
export default ModalSelection;
//# sourceMappingURL=ModalSelection.jsx.map