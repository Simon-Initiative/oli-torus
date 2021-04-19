import useWindowSize from "components/hooks/useWindowSize";
import React, { useEffect } from "react";
import { Provider } from "react-redux";
import AdaptivePageView from "./formats/adaptive/AdaptivePageView";
import store from "./store";
import { loadActivities, loadActivityState } from "./store/features/activities/slice";
import { loadPageState } from "./store/features/page/slice";

export interface DeliveryProps {
  resourceId: number;
  sectionSlug: string;
  userId: number;
  pageSlug: string;
  content: any;
  resourceAttemptState: any;
  resourceAttemptGuid: string;
  activityGuidMapping: any;
}

export const Delivery: React.FunctionComponent<DeliveryProps> = (
  props: DeliveryProps
) => {
  useEffect(() => {
    const {
      userId,
      resourceId,
      sectionSlug,
      pageSlug,
      content,
      resourceAttemptGuid,
      resourceAttemptState,
      activityGuidMapping,
    } = props;

    store.dispatch(
      loadPageState({
        userId,
        resourceId,
        sectionSlug,
        pageSlug,
        content,
        resourceAttemptGuid,
        resourceAttemptState,
        activityGuidMapping,
      })
    );

    // for the moment load *all* the activity state
    const attemptGuids = Object.keys(activityGuidMapping).map(
      (activityResourceId) => {
        const { attemptGuid } = activityGuidMapping[activityResourceId];
        return attemptGuid;
      }
    );
    store.dispatch(loadActivityState(attemptGuids));

    // for now we'll just load *all* the sequence items up front
    /* const activityIds = content.model
      .filter((item: any) => item.type === "activity-reference")
      .map((item: any) => item.activity_id);
    store.dispatch(loadActivities(activityIds)); */
  }, []);

  const parentDivClasses: string[] = [];
  if (props.content?.custom?.viewerSkin) {
    parentDivClasses.push(`skin-${props.content?.custom?.viewerSkin}`);
  }

  // this is something SS does...
  const { width: windowWidth } = useWindowSize();

  return (
    <Provider store={store}>
      <div className={parentDivClasses.join(" ")}>
        <div className="mainView" role="main" style={{ width: windowWidth }}>
          <AdaptivePageView />
        </div>
      </div>
      {/* <div>
        <h3>Advanced Delivery Mode</h3>

        <table className="table table-sm">
          <thead>
            <tr>
              <th>Attribute</th>
              <th>Value</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Resource Id:</td>
              <td>{props.resourceId}</td>
            </tr>
            <tr>
              <td>Resource Slug:</td>
              <td>{props.pageSlug}</td>
            </tr>
            <tr>
              <td>User Id:</td>
              <td>{props.userId}</td>
            </tr>
            <tr>
              <td>Section Slug:</td>
              <td>{props.sectionSlug}</td>
            </tr>
            <tr>
              <td>Content:</td>
              <td>{JSON.stringify(props.content)}</td>
            </tr>
          </tbody>
        </table>
      </div> */}
    </Provider>
  );
};
