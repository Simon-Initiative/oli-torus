/* eslint-disable react/prop-types */

import React, { useEffect, useState } from 'react';
const Accordion: React.FC<any> = (props) => {
  const tabs: [] = props.tabsData.tabs;

  const clickHandler = (tabid: any) => {
    if (expandedCards.includes(tabid))
      setExpandedCards(expandedCards.filter((i: any) => i !== tabid));
    else setExpandedCards([...expandedCards, tabid]);
  };

  const [expandedCards, setExpandedCards] = useState<any>([]);

  useEffect(() => {
    const tabsId = tabs.map((tab: any) => tab.id);
    setExpandedCards(tabsId);
  }, []);

  return (
    <div className="accordion">
      {tabs.map((tab: any) => (
        <div key={`card${tab.id}`} className="card">
          <div id={tab.id} className="d-flex justify-content-between py-2 border-bottom">
            <div
              className="col-10 font-weight-bold"
              data-toggle="collapse"
              data-target={`#collapse${tab.id}`}
              aria-expanded="true"
              aria-controls={`collapse${tab.id}`}
              onClick={() => {
                clickHandler(tab.id);
              }}
            >
              {expandedCards.includes(tab.id) ? (
                <i className="fa fa-angle-down my-1 mr-2"></i>
              ) : (
                <i className="fa fa-angle-right my-1 mr-2"></i>
              )}
              {tab.title}
            </div>
            <i className="fa fa-plus col-2 my-1"></i>
          </div>

          <div id={`collapse${tab.id}`} className="collapse show" aria-labelledby={tab.id}>
            <ul style={{ listStyleType: 'none' }}>
              {tab.data.map((item: any, index: number) => (
                <li key={`li${index}`}>{item}</li>
              ))}
            </ul>
          </div>
        </div>
      ))}
    </div>
  );
};

export default Accordion;
