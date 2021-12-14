import * as React from 'react';
import { connect } from 'react-redux';
const ModalDisplay = (props) => {
    const modals = props.modal
        .toArray()
        .reverse()
        .map((component, i) => <div key={i}>{component}</div>);
    return <div>{modals}</div>;
};
const mapStateToProps = (state, ownProps) => {
    const { modal } = state;
    return {
        modal,
    };
};
const mapDispatchToProps = (dispatch, ownProps) => {
    window.oliDispatch = dispatch;
    return {};
};
export const controller = connect(mapStateToProps, mapDispatchToProps)(ModalDisplay);
export { controller as ModalDisplay };
//# sourceMappingURL=ModalDisplay.jsx.map