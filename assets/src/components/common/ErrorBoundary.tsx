import React, { ErrorInfo } from 'react';
import Appsignal from '@appsignal/javascript';
import { Collapse } from 'components/common/Collapse';
import guid from 'utils/guid';

export const AppsignalContext = React.createContext<Appsignal | null>(null);
AppsignalContext.displayName = 'Appsignal';

const DefaultErrorMessage = () => (
  <>
    <p className="mb-4">Something went wrong. Please refresh the page and try again.</p>

    <hr />

    <p>If the problem persists, contact support with the following details:</p>
  </>
);

let lastReported: any = null;

export class ErrorBoundary extends React.Component<
  { errorMessage?: React.ReactNode; children: React.ReactNode },
  { hasError: boolean; error: Error | null; info: ErrorInfo | null; id: string }
> {
  static defaultProps = {
    errorMessage: <DefaultErrorMessage />,
  };

  constructor(props: any) {
    super(props);
    this.state = { hasError: false, error: null, info: null, id: guid() };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    // tslint:disable-next-line
    console.error(error);
    if (this.context) {
      if (lastReported !== error) {
        // lastReported is in case you have nested ErrorBoundaries so you only report an error once.
        const appsignal = this.context;
        appsignal.sendError(error);
        lastReported = error;
      }
    }

    this.setState({ hasError: true, error, info });
  }

  render() {
    try {
      if (this.state.hasError) {
        return (
          <ErrorMessage
            errorMessage={this.state.error?.message || ''}
            error={this.state.error}
            info={this.state.info}
          />
        );
      }
      return this.props.children;
    } catch (error) {
      // tslint:disable-next-line
      console.error(error);
    }
  }
}

interface ErrorMessageProps {
  errorMessage: string;
  error: Error | null;
  info?: React.ErrorInfo | null;
}

export const ErrorMessage: React.FC<ErrorMessageProps> = ({
  errorMessage,
  error,
  info,
  children,
}) => (
  <div className="alert alert-warning" role="alert">
    {errorMessage}
    <Collapse caption="Show error message">
      <div
        style={{
          fontFamily: 'monospace',
          wordBreak: 'break-word',
        }}
      >
        <h4>{error?.message}</h4>
        <p>{error?.stack}</p>
        <p>{info?.componentStack}</p>
      </div>
    </Collapse>
    {children}
  </div>
);

ErrorBoundary.contextType = AppsignalContext;
