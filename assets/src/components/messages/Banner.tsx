import * as React from 'react';
import { TransitionGroup, CSSTransition } from 'react-transition-group';
import { Message as Msg, MessageAction, Severity } from 'data/messages/messages';
import { Message } from './Message';

export interface BannerProps {
  dismissMessage: (message: Msg) => void;
  executeAction: (message: Msg, action: MessageAction) => void;
  messages: Msg[];
}

// Chooses the message with the highest priority, or the most recently triggered
// message given matching priorities
function highestPriority(messages: Msg[], severity: Severity): Msg[] {
  const m = messages.filter((m) => m.severity === severity).sort((a, b) => a.priority - b.priority);

  return m.length > 0 ? [m.pop() as any] : [];
}
// eslint-disable-next-line
export class Banner extends React.PureComponent<BannerProps, {}> {
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
      <div className="banner sticky-top">
        <TransitionGroup>
          {messages.map((m) => (
            <CSSTransition key={m.guid} timeout={{ enter: 200, exit: 200 }}>
              <Message key={m.guid} {...this.props} message={m} />
            </CSSTransition>
          ))}
        </TransitionGroup>
      </div>
    );
  }
}
