import React, { ReactNode } from 'react';

interface TabProps {
  label: React.ReactNode;
  index?: number;
  children: ReactNode;
}
const TabComponent: React.FunctionComponent<TabProps> = ({ index, children }) => (
  <div
    className={'tab-pane' + (index === 0 ? ' show active' : '')}
    id={'tab-' + index}
    role="tabpanel"
    aria-labelledby={'tab-' + index}
  >
    {children}
  </div>
);

// eslint-disable-next-line @typescript-eslint/no-empty-interface
interface TabsProps {}
const TabsComponent: React.FunctionComponent<TabsProps> = ({ children }) => {
  return (
    <>
      <ul className="nav nav-tabs mb-4" id="activity-authoring-tabs" role="tablist">
        {React.Children.map(children, (child, index) => {
          if (React.isValidElement(child) && isValidChild(child, TabbedNavigation)) {
            return (
              <li key={'tab-' + index} className="nav-item" role="presentation">
                <a
                  className={'nav-link' + (index === 0 ? ' active' : '')}
                  id={'link-tab-' + index}
                  data-toggle="tab"
                  href={'#tab-' + index}
                  role="tab"
                  aria-controls={'tab-' + index}
                  aria-selected="true"
                >
                  {child.props.label}
                </a>
              </li>
            );
          }
          return child;
        })}
      </ul>
      <div className="tab-content">
        {React.Children.map(
          children,
          (child, index) =>
            React.isValidElement(child) &&
            isValidChild(child, TabbedNavigation) &&
            React.cloneElement(child, { index, key: 'tab-content-' + index }),
        )}
      </div>
    </>
  );
};

export function isValidChild(child: any, component: any) {
  return Object.keys(component).reduce(
    (acc, key) => acc || child.type === (component as any)[key],
    false,
  );
}

export const TabbedNavigation = { Tabs: TabsComponent, Tab: TabComponent };
