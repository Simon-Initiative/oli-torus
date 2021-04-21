import * as React from 'react';
import * as Messages from 'data/messages/messages';
import { classNames } from 'utils/classNames';

export interface MessageProps {
  message: Messages.Message;
  dismissMessage: (message: Messages.Message) => void;
  executeAction: (message: Messages.Message, action: Messages.MessageAction) => void;
}

const classesForSeverity = {
  [Messages.Severity.Error]: 'alert alert-danger',
  [Messages.Severity.Warning]: 'alert alert-warning',
  [Messages.Severity.Information]: 'alert alert-info',
  [Messages.Severity.Task]: 'alert alert-light',
};
// eslint-disable-next-line
export class Message extends React.PureComponent<MessageProps, {}> {
  nav: any;

  constructor(props: MessageProps) {
    super(props);
  }

  onDismiss(e: any) {
    e.preventDefault();

    this.props.dismissMessage(this.props.message);
  }

  componentDidMount() {
    this.nav.scrollIntoView(true);
  }

  renderMessageAction(message: Messages.Message, action: Messages.MessageAction) {
    return (
      <button
        key={action.label}
        className={classNames(['btn btn-action', action.btnClass])}
        style={{ whiteSpace: 'nowrap' }}
        disabled={!action.enabled}
        onClick={() => this.props.executeAction(message, action)}
        type="button"
      >
        {action.label}
      </button>
    );
  }

  renderActions(message: Messages.Message) {
    if (message.canUserDismiss || message.actions.length > 0) {
      return (
        <div className="form-inline my-2 my-lg-0">
          {message.actions.map((a: Messages.MessageAction) => this.renderMessageAction(message, a))}
          {message.canUserDismiss && this.renderCloseButton()}
        </div>
      );
    }
  }

  renderCloseButton() {
    return (
      <button
        onClick={this.onDismiss.bind(this)}
        type="button"
        className="close"
        aria-label="Close"
      >
        <span aria-hidden="true">&times;</span>
      </button>
    );
  }

  renderMessage(content: JSX.Element | string) {
    return <div>{content}</div>;
  }

  render(): JSX.Element {
    const { message } = this.props;
    const classes =
      'message d-flex justify-content-between ' + classesForSeverity[message.severity];

    return (
      <div className={classes} ref={(nav) => (this.nav = nav)}>
        {this.renderMessage(message.content)}
        {this.renderActions(message)}
      </div>
    );
  }
}
