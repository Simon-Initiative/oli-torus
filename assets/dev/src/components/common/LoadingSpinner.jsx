import * as React from 'react';
export var LoadingSpinnerSize;
(function (LoadingSpinnerSize) {
    LoadingSpinnerSize[LoadingSpinnerSize["Small"] = 0] = "Small";
    LoadingSpinnerSize[LoadingSpinnerSize["Normal"] = 1] = "Normal";
    LoadingSpinnerSize[LoadingSpinnerSize["Large"] = 2] = "Large";
})(LoadingSpinnerSize || (LoadingSpinnerSize = {}));
export class LoadingSpinner extends React.PureComponent {
    constructor(props) {
        super(props);
    }
    render() {
        const { message, failed, children, size } = this.props;
        const sizeClass = size === LoadingSpinnerSize.Small
            ? 'ls-small'
            : size === LoadingSpinnerSize.Large
                ? 'ls-large'
                : 'ls-normal';
        return (<div className={'LoadingSpinner ' + sizeClass}>
        {failed ? (<i className="fa fa-times-circle"/>) : (<i className="fas fa-circle-notch fa-spin fa-1x fa-fw"/>)}
        &nbsp;{message ? message : children}
      </div>);
    }
}
//# sourceMappingURL=LoadingSpinner.jsx.map