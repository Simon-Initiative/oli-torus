import React from 'react';
import guid from 'utils/guid';
import { Collapse } from 'components/common/Collapse';

export class ErrorBoundary extends React.Component<any,
  { hasError: boolean, error: any, info: any, id: string }> {
  constructor(props: any) {
    super(props);
    this.state = { hasError: false, error: null, info: null, id: guid() };
  }

  componentDidCatch(error: any, info: any) {
    // tslint:disable-next-line
    console.log(error);

    this.setState({ hasError: true, error, info });
  }

  render() {
    try {

      if (this.state.hasError) {

        return (
          <div className="alert alert-warning" role="alert">
            <h4 className="alert-heading">Oh no!</h4>
            <p className="mb-4">Something went wrong.  Refresh the page and try again.</p>

            <hr/>

            <p>If the problem persists, contact OLI support with the following error message:</p>

            <Collapse caption="Show error message">
              <div>{this.state.error.stack}</div>
            </Collapse>

          </div>
        );

      }
      return this.props.children;

    } catch (error) {
      // tslint:disable-next-line
      console.log(error);
    }

  }

}
