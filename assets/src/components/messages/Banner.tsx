import * as React from 'react';
import ReactCSSTransitionGroup from 'react-addons-css-transition-group';
import { Message as Msg, MessageAction, Severity } from 'data/messages/messages';
import { Message } from './Message';
import './Banner.scss';

export interface BannerProps {
  dismissMessage: (message: Msg) => void;
  executeAction: (message: Msg, action: MessageAction) => void;
  messages: Msg[];
}

// Chooses the message with the highest priority, or the most recently triggered
// message given matching priorities
function highestPriority(
  messages: Msg[], severity: Severity)
  : Msg[] {

  const m = messages
    .filter(m => m.severity === severity)
    .sort((a, b) => a.priority - b.priority);

  return m.length > 0 ? [m.pop() as any] : [];
}

export class Banner
  extends React.PureComponent<BannerProps, {}> {

  constructor(props: BannerProps) {
    super(props);
  }


  render(): JSX.Element {

    // Only display one instance of each message severity at a time
    const errors = highestPriority(this.props.messages, Severity.Error);
    const warnings = highestPriority(this.props.messages, Severity.Warning);
    const infos = highestPriority(this.props.messages, Severity.Information);
    const tasks = highestPriority(this.props.messages, Severity.Task);

    const messages = [...errors, ...warnings, ...infos, ...tasks];

    return (
      <div className="banner">
        <ReactCSSTransitionGroup transitionName="message"
          transitionEnterTimeout={200} transitionLeaveTimeout={200}>
          {messages.map(m => <Message key={m.guid} {...this.props} message={m} />)}
        </ReactCSSTransitionGroup>
      </div>
    );

  }

}

