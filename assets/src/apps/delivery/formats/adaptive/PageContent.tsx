import React from "react";
import { useSelector } from "react-redux";
import { selectCurrentActivity } from "../../store/features/activities/slice";
import { selectPageContent } from "../../store/features/page/slice";
import ActivityRenderer from "./ActivityRenderer";

// TODO: need to factor this into a "legacy" flagged behavior
const InjectedStyles: React.FC = () => {
  return (
    <style>
      {`.content *  {text-decoration: none; padding: 0px; margin:0px;white-space: normal; font-family: Arial; font-size: 13px; font-style: normal;border: none; border-collapse: collapse; border-spacing: 0px;line-height: 1.4; color: black; font-weight:inherit;color: inherit; display: inline-block; -moz-binding: none; text-decoration: none; white-space: normal; border: 0px; max-width:none;}
        .content sup  {vertical-align: middle; font-size:65%; font-style:inherit;}
        .content sub  {vertical-align: middle; font-size:65%; font-style:inherit;}
        .content em  {font-style:italic; display:inline; font-size:inherit;}
        .content strong  {font-weight:bold; display:inline; font-size:inherit;}
        .content label  {margin-right:2px; display:inline-block; cursor:auto;}
        .content div  {display:inline-block; margin-top:1px}
        .content input  {margin:0px;}
        .content span  {display:inline; font-size:inherit;}
        .content option {display:block;}
        .content ul {display:block}
        .content ol {display:block}`}
    </style>
  );
};

const PageContent: React.FC = () => {
  const currentPage: any = useSelector(selectPageContent);
  const pageStyle: any = {
    // doesn't appear that SS is adding height
    // height: currentPage.custom?.defaultScreenHeight,
    width: currentPage.custom?.defaultScreenWidth,
  };
  const currentActivity = useSelector(selectCurrentActivity);

  return (
    <div className="stageContainer columnRestriction" style={pageStyle}>
      <InjectedStyles />
      <div id="stage-stage">
        <div className="stage-content-wrapper">
          {currentActivity ? (
            <ActivityRenderer parts={currentActivity?.content?.partsLayout} />
          ) : (
            <div>loading...</div>
          )}
        </div>
      </div>
    </div>
  );
};

export default PageContent;
