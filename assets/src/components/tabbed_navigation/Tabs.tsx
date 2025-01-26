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
    {React.Children.map(
      children,
      (child, _index) =>
        React.isValidElement(child) && React.cloneElement(child as any, { activetab: activeTab }),
    )}
  </div>
);

// eslint-disable-next-line @typescript-eslint/no-empty-interface
interface TabsComponentProps {}
const TabsComponent: React.FC<TabsComponentProps> = ({ children }) => {
  const [activeTab, setActiveTab] = useState(0);
  return (
    <>
      <ul className="nav nav-tabs my-2 flex justify-between" role="tablist">
        {React.Children.map(children, (child, index) => {
          if (React.isValidElement(child) && isValidChild(child, TabbedNavigation)) {
            return (
              <li key={'tab-' + index} className="nav-item" role="presentation">
                <button
                  onClick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    setActiveTab(index);
                  }}
                  className={'text-primary nav-link px-3' + (index === activeTab ? ' active' : '')}
                  data-bs-toggle="tab"
                  role="tab"
                  aria-controls={'tab-' + index}
                  aria-selected="true"
                >
                  {child.props.label}
                </button>
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
            React.cloneElement(child as any, { index, key: 'tab-content-' + index, activeTab }),
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
