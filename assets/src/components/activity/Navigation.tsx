import { ProjectSlug, ResourceSlug } from 'data/types';
import { SiblingActivity, ActivityContext } from 'data/content/activity';

const Sibling = ({ sibling, children, projectSlug, resourceSlug }
  : { sibling: SiblingActivity | null, children: any,
    projectSlug: ProjectSlug, resourceSlug: ResourceSlug }) => {

  if (sibling === null) {
    return (
      <li className="page-item disabled">
        <a className="page-link" href="#">{children}</a>
      </li>
    );
  }
  return (
    <li className="page-item">
      <a className="page-link"
        href={`/project/${projectSlug}/resource/${resourceSlug}/activity/${sibling.activitySlug}`}>
        {children}
      </a>
    </li>
  );

};

export const Navigation = (props: ActivityContext) => {

  const { projectSlug, resourceSlug, previousActivity, nextActivity } = props;

  return (
    <div className="d-flex justify-content-between">
      <nav aria-label="navigation">
        <ul className="pagination">
          <li className="page-item">
            <a className="btn btn-outline-primary"
              href={`/project/${projectSlug}/resource/${resourceSlug}`}>
              <i className="fas fa-arrow-left"></i> Return to Page
            </a>
          </li>
        </ul>
      </nav>
      <nav aria-label="navigation">
        <ul className="pagination">
          <Sibling projectSlug={projectSlug} resourceSlug={resourceSlug}
            sibling={previousActivity}>
            <i className="fas fa-arrow-circle-left"></i> Previous Activity
          </Sibling>
          <Sibling projectSlug={projectSlug} resourceSlug={resourceSlug}
            sibling={nextActivity}>
            Next Activity <i className="fas fa-arrow-circle-right"></i>
          </Sibling>
        </ul>
      </nav>
    </div>
  );

};

