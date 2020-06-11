import * as React from 'react';
import guid from 'utils/guid';

export interface Collapse {
  id: string;
}

export interface CollapseProps {
  caption: string;
  details?: string;
  expanded?: any; // Component to display in place of details when expanded
}

export interface CollapseState {
  collapsed: boolean;
}

export class Collapse extends React.PureComponent<CollapseProps, CollapseState> {

  constructor(props : CollapseProps) {
    super(props);

    this.id = guid();

    this.state = {
      collapsed: true,
    };

    this.onClick = this.onClick.bind(this);
  }

  onClick() {
    this.setState({ collapsed: !this.state.collapsed });
  }

  render() {

    const collapsedOrNot = this.state.collapsed ? 'collapse' : 'collapse.show';
    let detailsOrExpanded = null;
    if (this.props.details !== undefined && this.state.collapsed) {
      detailsOrExpanded = this.props.details;
    } else if (this.props.expanded !== undefined && !this.state.collapsed) {
      detailsOrExpanded = this.props.expanded;
    }

    const indicator = this.state.collapsed ? '+' : '-';

    return (
      <div>

        <button
          onClick={this.onClick}
          type="button"
          className="btn btn-link">
           {indicator} {this.props.caption}
        </button>
        {detailsOrExpanded}
        <div className={collapsedOrNot} id={this.id}>
          {this.props.children}
        </div>
      </div>
    );
  }

}

