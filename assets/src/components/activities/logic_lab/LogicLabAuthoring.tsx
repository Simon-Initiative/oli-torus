/*
Authoring mode interface for selecting LogicLab activities in Torus.

As a full authoring interface is not yet available, this simple interface
allows authors to select an activity from the list of the available activities.
Some basic filtering on the list has been implemented.
*/
import React, { FC, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { Manifest } from '../types';
import { LabActivity, LogicLabModelSchema } from './LogicLabModelSchema';

const STORE = configureStore();
const ACTIVITIES_URL = new URL('http://localhost:8080/api/v1/activities');

/**
 * A simple Bootstrap loading spinner component.
 * @returns A loading spinner component
 */
const Loading: FC = () => (
  <div className="spinner-border text-primary" role="status">
    <span className="visually-hidden sr-only">Loading...</span>
  </div>
);

/**
 * Checks if MathJax's typeset function is available and runs it.
 */
const typeset = () => {
  // Workaround limited MathJaxMinimal implementation.
  const math = window.MathJax as any;
  if (typeof math.typeset === 'function') {
    math.typeset();
  }
};

type DetailsProps = { activity?: LabActivity };

/**
 * Compontent for displaying activity summary details.
 * Useful in helping identify the selected activity.
 * Shows id, title, type, any keywords, any comments, dates, and any preview.
 * @component
 */
const Details: FC<DetailsProps> = ({ activity }: DetailsProps) => {
  if (!activity) {
    // if no activity then show warning.
    return <p className="alert alert-warning">No activity.</p>;
  }
  return (
    <div>
      <table className="table">
        <tbody>
          <tr>
            <th>Id:</th>
            <td>{activity.id}</td>
          </tr>
          <tr>
            <th>Type:</th>
            <td>{activity.spec.type}</td>
          </tr>
          <tr>
            <th>Title:</th>
            <td>{activity.title}</td>
          </tr>
          {activity.keywords.length && (
            <tr>
              <th>Keywords:</th>
              <td>{activity.keywords.join('/')}</td>
            </tr>
          )}
          {activity.comment && (
            <tr>
              <th>Comment:</th>
              <td>{activity.comment}</td>
            </tr>
          )}
          <tr>
            <th>Created:</th>
            <td>{new Date(activity.created).toLocaleString()}</td>
          </tr>
          <tr>
            <th>Last Modified:</th>
            <td>{new Date(activity.modified).toLocaleString()}</td>
          </tr>
        </tbody>
      </table>
      {activity.spec.preview && (
        <div className="card" dangerouslySetInnerHTML={{ __html: activity.spec.preview }}></div>
      )}
    </div>
  );
};

type LogicLabAuthoringProps = AuthoringElementProps<LogicLabModelSchema>;

/**
 * Authoring interface for LogicLab activities.
 * @component
 */
const Authoring: FC<LogicLabAuthoringProps> = (props: LogicLabAuthoringProps) => {
  const devmode = false; // Allows system developers to set some extra settings
  const { dispatch, model, editMode } = useAuthoringElementContext<LogicLabModelSchema>();
  const [activityId, setActivityId] = useState<string>(props.model.activity);
  const [servlet, setServlet] = useState<string>(props.model.src);
  useEffect(() => {
    setActivityId(model.activity);
    setServlet(model.src);
  }, [model]);

  // Current loading state.
  const [loading, setLoading] = useState<'loading' | 'loaded' | 'error'>('loading');
  const [servletError, setServletError] = useState(''); // last error from servlet call
  //const guid = useId(); // Needs react ^18
  const [id] = useState<string>(crypto.randomUUID()); // alternative to useId()

  // Set of flags bound to activity type filter checkboxes.
  const [includeArgument, setIncludeArgument] = useState(true);
  const [includeParse, setIncludeParse] = useState(true);
  const [includeDerivation, setIncludeDerivation] = useState(true);
  const [includeChase, setIncludeChase] = useState(true);
  const [includeTable, setIncludeTable] = useState(true);
  const [includeTree, setIncludeTree] = useState(true);
  const [includeSet, setIncludeSet] = useState(false);
  const allowSets = false; // sets not supported in lab officially, yet

  const [activities, setActivities] = useState<LabActivity[]>([]); // List of available activities
  const [activity, setActivity] = useState<LabActivity | undefined>(); // Currently selected activity

  // On mount, load the list of activities.
  useEffect(() => {
    const controller = new AbortController();
    const signal = controller.signal;
    const getActivities = async () => {
      // url should be relative to model.src, but is static for development.
      const response = await fetch(ACTIVITIES_URL, {
        signal,
        headers: { Accept: 'application/json' },
      });
      if (signal.aborted) {
        return;
      }
      if (!response.ok) {
        throw new Error(response.statusText);
      }
      const problems = (await response.json()) as LabActivity[];
      problems.sort((a, b) =>
        [...a.keywords, a.id].join('/').localeCompare([...b.keywords, b.id].join('/')),
      );
      setActivities(problems);
      setLoading('loaded');
    };
    getActivities().catch((err) => {
      console.error(err);
      setLoading('error');
      if (err instanceof Error) {
        setServletError(err.message);
      } else if (typeof err === 'string') {
        setServletError(err);
      } else {
        setServletError('Unknown error type.');
      }
    });

    // abort load if component rendering interupted.
    return () => controller.abort();
  }, []);

  // Set activity data when there are activities an an id.
  useEffect(() => {
    setActivity(activities?.find((a) => a.id === activityId));
  }, [activityId, activities]);

  // Typeset math in previews.
  useEffect(() => {
    if (activity) typeset();
  }, [activity]);

  return (
    <div className="card">
      <div className="card-title">AProS LogicLab Activity</div>
      {editMode && devmode && (
        <form>
          <div className="form-group">
            <label className="form-label">
              {/* Needed for development, to be removed when servlet is publicly hosted somewhere. */}
              AProS Servlet url:
              <input
                className="form-control"
                type="text"
                value={servlet}
                onChange={(e) => setServlet(e.target.value)}
              />
            </label>
          </div>
        </form>
      )}
      {loading === 'loading' && <Loading />}
      {loading === 'error' && (
        <div className="alert alert-danger">
          <details>
            <summary>LogicLab server is unreachable or not properly configured.</summary>
            {servletError}
          </details>
        </div>
      )}
      {loading === 'loaded' && (
        <>
          {editMode && (
            <form>
              <div className="flex items-baseline gap-2 flex-wrap">
                <span>Activity&nbsp;Types:</span>
                <div className="flex items-center">
                  <input
                    id={`$id_filter_argument`}
                    type="checkbox"
                    checked={includeArgument}
                    onChange={(e) => setIncludeArgument(e.target.checked)}
                  />
                  <label htmlFor={`$id_filter_argument`} className="ms-2 text-sm text-nowrap">
                    Argument&nbsp;Diagrams
                  </label>
                </div>
                <div className="flex items-center">
                  <input
                    id={`$id_filter_chase`}
                    type="checkbox"
                    checked={includeChase}
                    onChange={(e) => setIncludeChase(e.target.checked)}
                  />
                  <label htmlFor={`$id_filter_chase`} className="ms-2 text-sm text-nowrap">
                    Chasing&nbsp;Truth
                  </label>
                </div>
                <div className="flex items-center">
                  <input
                    id={`$id_filter_derivation`}
                    type="checkbox"
                    checked={includeDerivation}
                    onChange={(e) => setIncludeDerivation(e.target.checked)}
                  />
                  <label htmlFor={`$id_filter_derivation`} className="ms-2 text-sm text-nowrap">
                    Derivations
                  </label>
                </div>
                <div className="flex items-center">
                  <input
                    id={`$id_filter_parse`}
                    type="checkbox"
                    checked={includeParse}
                    onChange={(e) => setIncludeParse(e.target.checked)}
                  />
                  <label htmlFor={`$id_filter_parse`} className="ms-2 text-sm text-nowrap">
                    Parse Trees
                  </label>
                </div>
                <div className="flex items-center">
                  <input
                    id={`$id_filter_table`}
                    type="checkbox"
                    checked={includeTable}
                    onChange={(e) => setIncludeTable(e.target.checked)}
                  />
                  <label htmlFor={`$id_filter_table`} className="ms-2 text-sm text-nowrap">
                    Truth&nbsp;Tables
                  </label>
                </div>
                <div className="flex items-center">
                  <input
                    id={`$id_filter_tree`}
                    type="checkbox"
                    checked={includeTree}
                    onChange={(e) => setIncludeTree(e.target.checked)}
                  />
                  <label htmlFor={`$id_filter_tree`} className="ms-2 text-sm text-nowrap">
                    Truth&nbsp;Trees
                  </label>
                </div>
                {allowSets && (
                  <div className="flex items-center">
                    <input
                      id={`$id_filter_set`}
                      type="checkbox"
                      checked={includeSet}
                      onChange={(e) => setIncludeSet(e.target.checked)}
                    />
                    <label htmlFor={`$id_filter_set`} className="ms-2 text-sm text-nowrap">
                      Activity&nbsp;Set
                    </label>
                  </div>
                )}
              </div>
              <label htmlFor={id}>Select activity</label>
              <select
                className="form-select"
                id={id}
                value={activityId}
                onChange={(e) => {
                  dispatch((draft, _post) => {
                    draft.activity = e.target.value;
                  });
                }}
              >
                <option>---</option>
                {activities
                  .filter((p) => {
                    switch (p.spec.type) {
                      case 'parse_tree':
                        return includeParse;
                      case 'derivation':
                        return includeDerivation;
                      case 'chase_truth':
                        return includeChase;
                      case 'truth_table':
                        return includeTable;
                      case 'truth_tree':
                        return includeTree;
                      case 'argument_diagram':
                        return includeArgument;
                      case 'activities':
                        return includeSet;
                      default:
                        return true;
                    }
                  })
                  .map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.title}({p.spec.type}){/* [{p.keywords.join('/')}/{p.id}] */}
                    </option>
                  ))}
              </select>
            </form>
          )}

          <h5>Details:</h5>
          {activity ? (
            <>
              <div className="grid grid-cols-2">
                <h6>Id:</h6>
                <div>{activity.id}</div>
                <h6>Type:</h6>
                <div>{activity.spec.type}</div>
                <h6>Title:</h6>
                <div>{activity.title}</div>
                <h6>Keywords:</h6>
                <div>{activity.keywords.join('/')}</div>
                <h6>Created:</h6>
                <div>{new Date(activity.created).toLocaleString()}</div>
                <h6>Last Modified:</h6>
                <div>{new Date(activity.modified).toLocaleString()}</div>
              </div>
              {activity.spec.preview && (
                <div
                  className="card"
                  dangerouslySetInnerHTML={{ __html: activity.spec.preview }}
                ></div>
              )}
            </>
          ) : (
            <p>No selected activity.</p>
          )}
        </>
      )}
    </div>
  );
};

/**
 * Component for use in authoring mode when the user does not have edit permissions
 * for this activity.
 * Displays loading indicator and then the details of the activity.
 * @component
 */
const Preview: FC<LogicLabAuthoringProps> = (props: LogicLabAuthoringProps) => {
  // Current activity
  const [activity, setActivity] = useState<LabActivity | undefined>();
  // Loading state
  const [loading, setLoading] = useState<'loading' | 'loaded' | 'error'>('loading');

  // When props change, load the activity details.
  useEffect(() => {
    const controller = new AbortController();
    const signal = controller.signal;
    const getActivity = async () => {
      const response = await fetch(`${ACTIVITIES_URL.toString()}/${props.model.activity}`, {
        signal,
        headers: { Accept: 'application/json' },
      });
      if (signal.aborted) {
        return;
      }
      if (!response.ok) {
        throw new Error(response.statusText);
      }
      const spec = (await response.json()) as LabActivity;
      setActivity(spec);
      setLoading('loaded');
    };

    getActivity().catch((err) => {
      console.error(err);
      setLoading('error');
    });

    return () => controller.abort();
  }, [props]);

  // on setting activity, typeset the math.
  useEffect(() => {
    if (activity) {
      typeset();
    }
  }, [activity]);

  return (
    <>
      {loading === 'error' && (
        <div className="alert alert-warning">
          LogicLab server is unavailable. Please contact technical support.
        </div>
      )}
      {loading === 'loading' && <Loading />}
      {loading === 'loaded' && <Details activity={activity} />}
    </>
  );
};

/**
 * Torus authoring component for LogicLab activities.
 * @component
 */
export class LogicLabAuthoring extends AuthoringElement<LogicLabModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<LogicLabModelSchema>): void {
    ReactDOM.render(
      <Provider store={STORE}>
        <AuthoringElementProvider {...props}>
          {props.editMode ? <Authoring {...props} /> : <Preview {...props} />}
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.authoring.element, LogicLabAuthoring);
