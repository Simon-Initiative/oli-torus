import React, { useEffect, useState } from "react";
import ReactDOM from "react-dom";
import { Provider } from "react-redux";
import { configureStore } from "state/store";
import { AuthoringElement, AuthoringElementProps } from "../AuthoringElement";
import { AuthoringElementProvider, useAuthoringElementContext } from "../AuthoringElementProvider";
import { Manifest, makePart } from "../types";
import { LabActivity, LogicLabModelSchema } from "./LogicLabModelSchema";

const STORE = configureStore();

type LogicLabAuthoringProps = AuthoringElementProps<LogicLabModelSchema>;
const Authoring: React.FC<LogicLabAuthoringProps> = (props: LogicLabAuthoringProps) => {
  const { dispatch, model } = useAuthoringElementContext<LogicLabModelSchema>();
  const [activityId, setActivityId] = useState<string>(props.model.authoring.parts[0].id);
  useEffect(() => {
    const activity = model.authoring.parts[0].id;
    setActivityId(activity);
  }, [model]);

  //const guid = useId(); // Needs react ^18
  const [id] = useState<string>(crypto.randomUUID());
  const [activities, setActivities] = useState<LabActivity[]>([]);

  useEffect(() => {
    const getActivities = async () => {
      const response = await fetch('http://localhost:8080/api/v1/activities');
      if (!response.ok) throw new Error(response.statusText);
      const problems = await response.json() as LabActivity[];
      problems.sort((a, b) => [...a.keywords, a.id].join('/').localeCompare([...b.keywords, b.id].join('/')));
      setActivities(problems);
    }
    getActivities().catch(console.error);
  }, []);

  return (
    <form>
      <h3>LogicLab Activity Selection</h3>
      <div className="form-group">
        <label htmlFor={id}>Select activity</label>
        <select id={id} value={activityId} onChange={(e) => {
          dispatch((draft, _post) => {
            draft.authoring.parts[0] = makePart([], undefined, e.target.value);
          });
        }}>
          <option>---</option>
          {activities.map(p =>
            <option key={p.id} value={p.id}>
              {p.title}
              ({p.spec.type})
              [{p.keywords.join('/')}/{p.id}]</option>
          )}
        </select>
      </div>
    </form>
  )
}

export class LogicLabAuthoring extends AuthoringElement<LogicLabModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<LogicLabModelSchema>): void {
    ReactDOM.render(
      <Provider store={STORE}>
        <AuthoringElementProvider {...props}>
          <Authoring {...props} />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    )
  }
}

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.authoring.element, LogicLabAuthoring);
