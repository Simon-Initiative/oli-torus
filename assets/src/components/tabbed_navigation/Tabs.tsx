import React, { ReactNode, useState } from 'react';

interface TabProps {
  label: React.ReactNode;
  index?: number;
  children: ReactNode;
  activeTab?: number;
}
const TabComponent: React.FunctionComponent<TabProps> = ({ index, children, activeTab }) => (
  <div
    className={'tab-pane' + (index === activeTab ? ' show active' : '')}
    role="tabpanel"
    aria-labelledby={'tab-' + index}
  >
    {children}
  </div>
);

// eslint-disable-next-line @typescript-eslint/no-empty-interface
interface TabsComponentProps {}
const TabsComponent: React.FC<TabsComponentProps> = ({ children }) => {
  const [activeTab, setActiveTab] = useState(0);
  return (
    <>
      <ul className="nav nav-tabs mb-4" id="activity-authoring-tabs" role="tablist">
        {React.Children.map(children, (child, index) => {
          if (React.isValidElement(child) && isValidChild(child, TabbedNavigation)) {
            return (
              <li key={'tab-' + index} className="nav-item" role="presentation">
                <a
                  onClick={(e) => setActiveTab(index)}
                  className={'nav-link' + (index === 0 ? ' active' : '')}
                  data-toggle="tab"
                  href="#"
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
            React.cloneElement(child, { index, key: 'tab-content-' + index, activeTab }),
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
