import React from 'react';

type EditorErrorBoundaryProps = {
  id: string;
  children: unknown;
};

interface EditorErrorBoundaryState {
  hasError: boolean;
  error: unknown;
}

export class EditorErrorBoundary extends React.Component<
  EditorErrorBoundaryProps,
  EditorErrorBoundaryState
> {
  constructor(props: EditorErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false, error: undefined };
  }

  static getDerivedStateFromError(error: unknown) {
    // Update state so the next render will show the fallback UI.
    return { hasError: true, error: error };
  }

  componentDidCatch(error: unknown, errorInfo: unknown) {
    // You can also log the error to an error reporting service
    // for now just log it to the console
    console.error(error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="alert alert-danger" role="alert">
          Something went wrong. This item could not be displayed.
          <span className="float-right">
            <small>
              <b>ID:</b> {this.props.id}
            </small>
          </span>
        </div>
      );
    }

    return this.props.children;
  }
}
