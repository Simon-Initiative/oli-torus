/* eslint-disable react/prop-types */

import React, { useEffect, useState } from 'react';
const TabStrip: React.FC<any> = (props) => {
  const tabs: any[] = props.tabsData.tabs;
  const clickHandler = (tabid: any) => {
    setSelectedTab(tabid);
  };
  const [selectedTab, setSelectedTab] = useState<any>('');
  useEffect(() => {
    setSelectedTab(tabs[0].id);
  }, []);
  return (
    <div>
      <ul className="nav nav-tabs" role="tablist">
        {tabs.map((tab: any) => (
          <li
            role="tab"
            key={`${tab.id}-tab`}
            data-toggle="tab"
            aria-controls={`tab${tab.id}`}
            aria-selected={selectedTab == tab.id}
            className={`nav-item ${selectedTab == tab.id ? 'active font-weight-bold' : ''} p-2`}
            /* href={`#tab${tab.id}`} */
            onClick={() => {
              clickHandler(tab.id);
            }}
          >
            <span className={selectedTab == tab.id ? 'border-top' : ''}>{tab.title}</span>
          </li>
        ))}
      </ul>

      <div className="tab-content" id="myTabContent">
        {tabs.map((tab: any) => (
          <div
            className={`tab-pane fade${selectedTab == tab.id ? ' show active' : ''}`}
            key={`tab${tab.id}`}
            role="tabpanel"
            aria-labelledby={`${tab.id}-tab`}
          >
            {tab.data}
          </div>
        ))}
      </div>
    </div>
  );
};

export default TabStrip;
