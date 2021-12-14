import React from 'react';
import guid from 'utils/guid';
import { Collapse } from 'components/common/Collapse';
export class ErrorBoundary extends React.Component {
    constructor(props) {
        super(props);
        this.state = { hasError: false, error: null, info: null, id: guid() };
    }
    componentDidCatch(error, info) {
        // tslint:disable-next-line
        console.error(error);
        this.setState({ hasError: true, error, info });
    }
    render() {
        var _a, _b, _c;
        try {
            if (this.state.hasError) {
                return (<div className="alert alert-warning" role="alert">
            <h4 className="alert-heading">Oh no!</h4>
            <p className="mb-4">Something went wrong. Refresh the page and try again.</p>

            <hr />

            <p>If the problem persists, contact OLI support with the following error message:</p>

            <Collapse caption="Show error message">
              <div style={{
                        fontFamily: 'monospace',
                        wordBreak: 'break-word',
                    }}>
                <h4>{(_a = this.state.error) === null || _a === void 0 ? void 0 : _a.message}</h4>
                <p>{(_b = this.state.error) === null || _b === void 0 ? void 0 : _b.stack}</p>
                <p>{(_c = this.state.info) === null || _c === void 0 ? void 0 : _c.componentStack}</p>
              </div>
            </Collapse>
          </div>);
            }
            return this.props.children;
        }
        catch (error) {
            // tslint:disable-next-line
            console.error(error);
        }
    }
}
//# sourceMappingURL=ErrorBoundary.jsx.map