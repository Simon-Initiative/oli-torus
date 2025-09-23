/*
Authoring mode interface for selecting LogicLab activities in Torus.

As a full authoring interface is not yet available, this simple interface
allows authors to select an activity from the list of the available activities.
Some basic filtering on the list has been implemented.
*/
import React, { FC, useEffect, useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { LoadingSpinner } from 'components/common/LoadingSpinner';
import { getGlobalLastPromise, setGlobalLastPromise } from 'components/common/MathJaxFormula';
import { configureStore } from 'state/store';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { Manifest, PostUndoable, makeUndoable } from '../types';
import {
  AllActivityTypes,
  LabActivity,
  LogicLabModelSchema,
  getLabServer,
  isLabActivity,
  maxPoints,
  translateActivityType,
  useLabServer,
} from './LogicLabModelSchema';

const STORE = configureStore();

/**
 * Checks if MathJax's typeset function is available and runs it.
 */
const typeset = () => {
  // abort if MathJax is not available.
  if (typeof window.MathJax === 'undefined') {
    return;
  }
  if (typeof window.MathJax.typesetPromise === 'function') {
    // Torus idiom to manage unique MathJax async typesetting promise to avoid concurrency issues
    let lastPromise = getGlobalLastPromise();
    lastPromise = lastPromise.then(() => window.MathJax.typesetPromise());
    setGlobalLastPromise(lastPromise);
  }
};

type DetailsProps = { activity?: LabActivity };

/**
 * Component for displaying activity summary details.
 * Useful in helping identify the selected activity.
 * Shows id, title, type, any keywords, any comments, dates, and any preview.
 * @component
 */
const Details: FC<DetailsProps> = ({ activity }) => {
  if (!isLabActivity(activity)) {
    // if no activity then show warning.
    return <p className="alert alert-warning">No activity.</p>;
  }
  return (
    <div>
      <table className="table table-striped table-bordered table-sm">
        <tbody>
          <tr>
            <th scope="row" className="text-start">
              Id:
            </th>
            <td>{activity.id}</td>
          </tr>
          <tr>
            <th scope="row" className="text-start">
              Type:
            </th>
            <td>
              {translateActivityType(activity.spec.type)}
              {activity.spec.type === 'derivation' ? (
                <span className="badge bg-info mx-2">
                  {activity.spec.tutor ? 'Tutored' : 'Untutored'}
                </span>
              ) : null}
            </td>
          </tr>
          <tr>
            <th scope="row" className="text-start">
              Title:
            </th>
            <td>{activity.title}</td>
          </tr>
          {activity.keywords.length ? (
            <tr>
              <th scope="row" className="text-start">
                Keywords:
              </th>
              <td>{activity.keywords.join('/')}</td>
            </tr>
          ) : null}
          {activity.comment ? (
            <tr>
              <th scope="row" className="text-start">
                Comment:
              </th>
              <td>{activity.comment}</td>
            </tr>
          ) : null}
          <tr>
            <th scope="row" className="text-start">
              Created:
            </th>
            <td>{activity.created && new Date(activity.created).toLocaleString()}</td>
          </tr>
          <tr>
            <th scope="row" className="text-start">
              Last Modified:
            </th>
            <td>{activity.modified && new Date(activity.modified).toLocaleString()}</td>
          </tr>
        </tbody>
      </table>
      {activity.spec.preview && (
        <div className="card" dangerouslySetInnerHTML={{ __html: activity.spec.preview }}></div>
      )}
    </div>
  );
};

// To be used to update the activity in the model as part of a dispatch.
const updateActivity =
  (activity: LabActivity, source?: string) => (model: LogicLabModelSchema, post: PostUndoable) => {
    post(
      makeUndoable('Set LogicLab activity', [
        Operations.replace('$.activity', clone(model.activity)),
        Operations.setKey('$.authoring', 'source', model.authoring.source),
        Operations.setKey('$.authoring.parts[0]', 'outOf', maxPoints(model.activity)),
      ]),
    );
    Operations.apply(model, Operations.replace('$.activity', activity));
    Operations.apply(model, Operations.setKey('$.authoring', 'source', source));
    Operations.apply(
      model,
      Operations.setKey('$.authoring.parts[0]', 'outOf', maxPoints(activity)),
    );
  };

// Check fetch response for bad responses statuses and throws if needed.
const checkResponse = async (response: Response) => {
  if (!response.ok) {
    if (response.status === 403) {
      throw new Error('You do not have permission to access the LogicLab server.');
    }
    if (response.status === 404) {
      throw new Error(
        'LogicLab server is not configured for this Torus instance. Please contact support.',
      );
    }
    if (response.status === 500) {
      throw new Error('Internal LogicLab server error. Please contact technical support.');
    }
    if (response.status === 400) {
      // TODO process the error json message from the server.
      const error = await response.json();
      throw new Error(error.detail.message ?? 'Invalid File.');
    }
    throw new Error(response.statusText || 'LogicLab server returned an error.');
  }
};

/**
 * Custom hook to fetch the list of LogicLab activities available on the server.
 * @param authoringContext - the authoring context containing the LogicLab server URL.
 * @returns
 */
const useLogicLabActivityList = (server?: string) => {
  const [activities, setActivities] = useState<LabActivity[]>([]);
  const [loading, setLoading] = useState<'loading' | 'loaded' | 'error'>('loading');
  const [servletError, setError] = useState<string>(''); // last error from servlet call
  const controller = useRef<AbortController | null>(null);
  const handleError = (err: unknown) => {
    if (err instanceof Error && err.name === 'AbortError') {
      // ignore abort errors
      return;
    }
    console.error(err);
    setLoading('error');
    if (err instanceof ReferenceError) {
      setError(
        'LogicLab server is not configured for this Torus instance.  Please contact support.',
      );
    } else if (err instanceof Error && err.message) {
      setError(err.message);
    } else if (typeof err === 'string') {
      setError(err);
    } else {
      setError('Unknown error type.');
    }
  };
  useEffect(() => {
    if (server) {
      // fix for uninitialized server parameter.
      controller.current = new AbortController();
      const signal = controller.current.signal;
      const getActivities = async () => {
        setLoading('loading');
        try {
          const url = new URL('api/v1/activities', server);
          const response = await fetch(
            url.toString(), // tsc does not allow URL as parameter, contrary to MDM spec.
            {
              signal,
              headers: { Accept: 'application/json' },
            },
          );
          if (signal.aborted) {
            return;
          }
          await checkResponse(response);
          const problems = (await response.json()) as LabActivity[];
          problems.sort((a, b) =>
            [...a.keywords, a.id].join('/').localeCompare([...b.keywords, b.id].join('/')),
          );
          setActivities(problems);
          setLoading('loaded');
          controller.current = null;
        } catch (err) {
          handleError(err);
        }
      };
      getActivities().catch(handleError);
    }
    // abort load if component rendering interrupted.
    return () => controller.current?.abort('Component unmounted or server changed.');
  }, [server]);
  return { activities, loading, servletError };
};

/** Generate a unique id, shim for react^18's useId. */
const useId = (): string => {
  const [id] = useState<string>(crypto.randomUUID());
  return id;
};

type FilterCheckboxProps = {
  name: string;
  disabled?: boolean;
  checked?: boolean;
  onChange: (target: string, checked: boolean) => void;
};
const FilterCheckbox: FC<FilterCheckboxProps> = ({ name, disabled, checked, onChange }) => {
  const id = useId();
  return (
    <div className="flex items-center">
      <input
        type="checkbox"
        id={id}
        name={name}
        disabled={disabled}
        checked={checked}
        onChange={(e) => onChange(name, e.target.checked)}
        className="rounded-sm"
      />
      <label className="mx-2 ms-2 text-sm font-medium text-nowrap" htmlFor={id}>
        {translateActivityType(name)}
      </label>
    </div>
  );
};

type LogicLabAuthoringProps = AuthoringElementProps<LogicLabModelSchema>;

/**
 * Authoring interface for LogicLab activities.
 * @component
 */
const Authoring: FC<LogicLabAuthoringProps> = (props: LogicLabAuthoringProps) => {
  const { dispatch, model, editMode, authoringContext } =
    useAuthoringElementContext<LogicLabModelSchema>();

  const [activityId, setActivityId] = useState<string | LabActivity>(props.model.activity);
  useEffect(() => {
    setActivityId(model.activity);
  }, [model.activity]);

  const id = useId();

  // Set of flags bound to activity type filter checkboxes.
  const allowSets = false; // sets not supported in lab officially, yet
  const [filters, setFilters] = useState<string[]>(AllActivityTypes); // current set of filters
  const setFilter = (type: string, checked: boolean) => {
    setFilters((prev) => {
      if (checked) {
        if (prev.includes(type)) return prev;
        return [...prev, type];
      } else {
        return prev.filter((t) => t !== type);
      }
    });
  };
  const [search, setSearch] = useState<string>(''); // current text filter

  const [activity, setActivity] = useState<LabActivity | undefined>(); // Currently selected activity
  const server = useLabServer(authoringContext);
  const { activities, loading, servletError } = useLogicLabActivityList(server);

  const [invalid, setInvalid] = useState<string>(''); // invalid file message

  // Set activity data when there are activities and an id.
  useEffect(() => {
    if (isLabActivity(activityId)) {
      setActivity(activityId);
      return;
    }
    setActivity(activities?.find((a) => a.id === activityId));
  }, [activityId, activities]);

  // Typeset math in previews.
  useEffect(() => {
    if (activity) typeset();
  }, [activity]);

  const [sort, setSort] = useState<string>('id-asc'); // current sort order
  const isTutored = (activity: LabActivity | string | undefined): boolean =>
    isLabActivity(activity) && activity?.spec.type === 'derivation' && !!activity?.spec.tutor;
  const [tutor, setTutor] = useState<boolean>(isTutored(props.model.activity)); // tutoring mode for derivation activities
  useEffect(() => {
    setTutor(isTutored(activity));
  }, [activity]);

  return (
    <>
      {loading === 'error' && (
        <div className="alert alert-danger">
          <details>
            <summary>LogicLab server is unreachable or not properly configured.</summary>
            {servletError}
          </details>
        </div>
      )}
      {editMode && (
        <div className="w-full p-2 border border-secondary rounded-lg shadow-sm">
          <form>
            <p>Either select an existing activity or upload a new one.</p>
            <div className="mx-3 ml-5 ms-5 mb-2">
              <span className="text-sm font-medium">
                Activity&nbsp;Types included in selection:
              </span>
              <div className="flex items-baseline gap-2 flex-wrap border border-secondary rounded-lg p-1">
                <FilterCheckbox
                  name="argument_diagram"
                  checked={filters.includes('argument_diagram')}
                  onChange={setFilter}
                  disabled={!activities || activities.length === 0 || loading === 'loading'}
                />
                <FilterCheckbox
                  name="chase_truth"
                  checked={filters.includes('chase_truth')}
                  onChange={setFilter}
                  disabled={!activities || activities.length === 0 || loading === 'loading'}
                />
                <FilterCheckbox
                  name="derivation"
                  checked={filters.includes('derivation')}
                  onChange={setFilter}
                  disabled={!activities || activities.length === 0 || loading === 'loading'}
                />
                <FilterCheckbox
                  name="parse_tree"
                  checked={filters.includes('parse_tree')}
                  onChange={setFilter}
                  disabled={!activities || activities.length === 0 || loading === 'loading'}
                />
                <FilterCheckbox
                  name="truth_table"
                  checked={filters.includes('truth_table')}
                  onChange={setFilter}
                  disabled={!activities || activities.length === 0 || loading === 'loading'}
                />
                <FilterCheckbox
                  name="truth_tree"
                  checked={filters.includes('truth_tree')}
                  onChange={setFilter}
                  disabled={!activities || activities.length === 0 || loading === 'loading'}
                />
                {allowSets ? (
                  <FilterCheckbox
                    name="activities"
                    checked={filters.includes('activities')}
                    onChange={setFilter}
                    disabled={!activities || activities.length === 0 || loading === 'loading'}
                  />
                ) : null}
              </div>
            </div>
            <div className="mx-3 ml-5 ms-5 mb-2 flex flex-wrap">
              <span className="mr-2 me-2 text-sm font-medium">Sort Activities in selection:</span>
              <ul className="items-center inline w-fit text-sm font-medium border border-secondary rounded-lg flex">
                <li className="border-b border-secondary sm:border-b-0 sm:border-r">
                  <label className="mx-2 my-1">
                    <input
                      type="radio"
                      name="sort"
                      value="id-asc"
                      className="mx-1"
                      checked={sort === 'id-asc'}
                      onChange={() => setSort('id-asc')}
                    />
                    Id <i className="fa-solid fa-sort-alpha-down"></i>
                  </label>
                </li>
                <li className="border-b border-secondary sm:border-b-0 sm:border-r">
                  <label className="mx-2 my-1">
                    <input
                      type="radio"
                      name="sort"
                      value="id-dec"
                      className="mx-1"
                      checked={sort === 'id-dec'}
                      onChange={() => setSort('id-dec')}
                    />
                    Id <i className="fa-solid fa-sort-alpha-up"></i>
                  </label>
                </li>
                <li className="border-b border-secondary sm:border-b-0 sm:border-r">
                  <label className="mx-2 my-1">
                    <input
                      type="radio"
                      name="sort"
                      value="title"
                      className="mx-1"
                      checked={sort === 'title-asc'}
                      onChange={() => setSort('title-asc')}
                    />
                    Title <i className="fa-solid fa-sort-alpha-down"></i>
                  </label>
                </li>
                <li className="">
                  <label className="mx-2 my-1">
                    <input
                      type="radio"
                      name="sort"
                      value="title-dec"
                      className="mx-1"
                      checked={sort === 'title-dec'}
                      onChange={() => setSort('title-dec')}
                    />
                    Title <i className="fa-solid fa-sort-alpha-up"></i>
                  </label>
                </li>
              </ul>
            </div>
            <div className="m-3 ms-5 ml-5 flex flex-row gap-2 items-center">
              <label htmlFor={`${id}-search`} className="flex-none text-sm font-medium">
                Text Filter:
              </label>
              <div className="flex grow">
                <input
                  id={`${id}-search`}
                  type="text"
                  placeholder="Filter on id, title, keywords, and comment"
                  className="border rounded-none rounded-s-lg rounded-l-lg w-full"
                  value={search}
                  onChange={(e) => {
                    setSearch(e.target.value.trim());
                  }}
                />
                <button
                  type="button"
                  className="btn btn-secondary rounded-none rounded-e-lg rounded-r-lg"
                  onClick={() => setSearch('')}
                >
                  <i className="fa-solid fa-broom"></i>
                </button>
              </div>
            </div>
            <div className="m-3">
              <label htmlFor={id} className="font-medium text-primary">
                Select activity
              </label>
              <select
                className="border rounded-lg focus:ring-primary focus:border-primary block w-full p-2.5"
                id={id}
                value={isLabActivity(activityId) ? activityId.id : activityId}
                disabled={!activities || activities.length === 0 || loading === 'loading'}
                onChange={(e) => {
                  const id = e.target.value;
                  const activity = activities.find((a) => a.id === id);
                  if (!activity) return;
                  dispatch(updateActivity(activity));
                }}
              >
                <option>---</option>
                {[...activities] // copy to avoid mutating original, use .toSorted with lib target es2023+
                  .filter(
                    (p) =>
                      filters.includes(p.spec.type) ||
                      (isLabActivity(activityId) ? activityId.id : activityId) === p.id,
                  ) // include if type is selected
                  .filter((p) => {
                    if (!search) return true;
                    const needle = search.toLowerCase();
                    if (p.id.toLowerCase().includes(needle)) return true;
                    if (p.title.toLowerCase().includes(needle)) return true;
                    if (p.keywords.some((k) => k.toLowerCase().includes(needle))) return true;
                    if (p.comment && p.comment.toLowerCase().includes(needle)) return true;
                    return false;
                  })
                  .sort(
                    (a, b) =>
                      (sort.endsWith('-asc') ? 1 : -1) *
                      (sort.includes('title')
                        ? a.title.localeCompare(b.title)
                        : a.id.localeCompare(b.id)),
                  )
                  .map((p) => (
                    <option key={p.id} value={p.id} className="overflow-hidden text-ellipsis">
                      {p.title} ({translateActivityType(p.spec.type)})
                    </option>
                  ))}
              </select>
            </div>
            <hr className="mt-2 w-3/4 mx-auto" />
            <div className="m-3">
              <label htmlFor={`${id}_formFile`} className="block mb-1 font-medium text-primary">
                Upload activity XML file
              </label>
              <input
                disabled={!server}
                className={`block w-full text-sm border rounded cursor-pointer focus:outline-none ${
                  invalid
                    ? 'border-danger text-danger placeholder-danger focus:ring-danger focus:border-danger'
                    : 'border-secondary focus:ring-secondary focus:border-secondary'
                }`}
                type="file"
                id={`${id}_formFile`}
                accept="text/xml,application/xml"
                onChange={async (e) => {
                  setInvalid(
                    server
                      ? ''
                      : 'LogicLab server is not configured for this Torus instance.  Please contact support.',
                  );
                  if (server && e.target.files?.length) {
                    try {
                      const endpoint = new URL('api/v1/activities', server);
                      const response = await fetch(endpoint.toString(), {
                        method: 'POST',
                        body: e.target.files[0],
                      });
                      await checkResponse(response);
                      const spec = await response.json();
                      if (!isLabActivity(spec)) {
                        throw new TypeError(
                          'Uploaded file does not contain a valid LogicLab activity.',
                        );
                      }
                      setActivityId('');
                      setActivity(spec);
                      dispatch(updateActivity(spec, await e.target.files[0].text()));
                    } catch (err) {
                      if (err instanceof TypeError) {
                        setInvalid(err.message);
                      } else if (err instanceof Error && err.message) {
                        setInvalid(err.message);
                      } else if (typeof err === 'string') {
                        setInvalid(err);
                      } else {
                        setInvalid('Unknown error type.');
                      }
                      console.error(err);
                    }
                  }
                }}
              />
              {invalid ? <div className="text-danger">{invalid}</div> : null}
            </div>
          </form>
        </div>
      )}
      {activity?.spec.type === 'derivation' ? (
        <div className="m-3">
          <label className="inline-flex items-center cursor-pointer">
            <input
              type="checkbox"
              value="tutor"
              checked={tutor}
              className="sr-only peer"
              onChange={(e) => {
                setActivity((prev) => {
                  // tutor is updated via effect.
                  if (isLabActivity(prev) && prev.spec.type === 'derivation') {
                    const next = clone(prev);
                    next.spec.tutor = e.target.checked;
                    dispatch(updateActivity(next));
                    return next;
                  }
                  return prev;
                });
              }}
            />
            <div className="relative w-11 h-6 bg-secondary peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-primary rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
            <span className="ms-2 ml-2 text-sm font-medium">Tutor</span>
          </label>
        </div>
      ) : null}
      <h5>Details:</h5>
      {activity ? (
        <Details activity={activity} />
      ) : (
        <p className="alert alert-warning">No selected activity.</p>
      )}
    </>
  );
};

/**
 * Component for use in authoring mode when the user does not have edit permissions
 * for this activity.
 * Displays loading indicator and then the details of the activity.
 * @component
 */
const Preview: FC<LogicLabAuthoringProps> = ({
  model,
  authoringContext,
}: LogicLabAuthoringProps) => {
  // Current activity
  const [activity, setActivity] = useState<LabActivity | undefined>();
  // Loading state
  const [loading, setLoading] = useState<'loading' | 'loaded'>('loading');

  const controller = useRef<AbortController | null>(null);
  // When props change, load the activity details.
  useEffect(() => {
    const getActivity = async () => {
      if (isLabActivity(model.activity)) {
        setActivity(model.activity);
        setLoading('loaded');
        return;
      }
      if (model.activity) {
        controller.current = new AbortController();
        const signal = controller.current.signal;
        setLoading('loading');
        const server = getLabServer(authoringContext);
        const url = new URL(`api/v1/activities/${model.activity}`, server);
        const response = await fetch(url.toString(), {
          signal,
          headers: { Accept: 'application/json' },
        });
        if (signal.aborted) {
          return;
        }
        if (!response.ok) {
          throw new Error(`Failed to load activity details: ${response.statusText}`);
        }
        await checkResponse(response);
        const spec = await response.json();
        if (!isLabActivity(spec)) {
          throw new TypeError('Configured activity is not valid.');
        }
        setActivity(spec);
        setLoading('loaded');
        controller.current = null;
        return;
      }
      throw new TypeError(
        'LogicLab activity is not set.  Please have the content author configure this activity.',
      );
    };

    getActivity().catch((err) => {
      if (err instanceof Error && err.name === 'AbortError') {
        // ignore abort errors
        return;
      }
      throw err;
    }); // let error boundary handle errors

    return () => controller.current?.abort('Component unmounted or model changed.');
  }, [model, authoringContext]);

  // on setting activity, typeset the math.
  useEffect(() => {
    if (activity) {
      typeset();
    }
  }, [activity]);

  return (
    <>
      {loading === 'loading' && <LoadingSpinner />}
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
          <div className="card">
            <h4 className="card-title">AProS LogicLab Activity</h4>
            <div className="card-content">
              <ErrorBoundary>
                {props.editMode ? <Authoring {...props} /> : <Preview {...props} />}
              </ErrorBoundary>
            </div>
          </div>
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.authoring.element, LogicLabAuthoring);
