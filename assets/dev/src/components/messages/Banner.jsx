import * as React from 'react';
import { TransitionGroup, CSSTransition } from 'react-transition-group';
import { Severity } from 'data/messages/messages';
import { Message } from './Message';
// Chooses the message with the highest priority, or the most recently triggered
// message given matching priorities
function highestPriority(messages, severity) {
    const m = messages.filter((m) => m.severity === severity).sort((a, b) => a.priority - b.priority);
    return m.length > 0 ? [m.pop()] : [];
}
// eslint-disable-next-line
export class Banner extends React.PureComponent {
    constructor(props) {
        super(props);
    }
    render() {
        // Only display one instance of each message severity at a time
        const errors = highestPriority(this.props.messages, Severity.Error);
        const warnings = highestPriority(this.props.messages, Severity.Warning);
        const infos = highestPriority(this.props.messages, Severity.Information);
        const tasks = highestPriority(this.props.messages, Severity.Task);
        const messages = [...errors, ...warnings, ...infos, ...tasks];
        return (<div className="banner sticky-top">
        <TransitionGroup>
          {messages.map((m) => (<CSSTransition key={m.guid} timeout={{ enter: 200, exit: 200 }}>
              <Message key={m.guid} {...this.props} message={m}/>
            </CSSTransition>))}
        </TransitionGroup>
      </div>);
    }
}
//# sourceMappingURL=Banner.jsx.map