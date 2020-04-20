import { ProjectSlug, ResourceSlug } from 'data/types';
import { SiblingActivity, ActivityContext } from 'data/content/activity';

const Sibling = ({ sibling, prefix, projectSlug, resourceSlug }
  : { sibling: SiblingActivity | null, prefix: string,
    projectSlug: ProjectSlug, resourceSlug: ResourceSlug }) => {

  if (sibling === null) {
    return (
      <li className="page-item disabled">
        <a className="page-link" href="#">{prefix}</a>
      </li>
    );
  }
  return (
    <li className="page-item">
      <a className="page-link"
        href={`/project/${projectSlug}/resource/${resourceSlug}/activity/${sibling.activitySlug}`}>
        {prefix}
      </a>
    </li>
  );

};

export const Navigation = (props: ActivityContext) => {

  const { projectSlug, resourceSlug, previousActivity, nextActivity } = props;

  return (
    <div className="d-flex justify-content-between" style={ { paddingRight: '20px' } }>
      <nav aria-label="navigation">
        <ul className="pagination">
          <li className="page-item">
            <a className="page-link"
              href={`/project/${projectSlug}/resource/${resourceSlug}`}>
              &lt;&lt; Back to Page
            </a>
          </li>
        </ul>
      </nav>
      <nav aria-label="navigation">
        <ul className="pagination">
          <Sibling projectSlug={projectSlug} resourceSlug={resourceSlug}
            sibling={previousActivity} prefix="< Previous Activity"/>
          <Sibling projectSlug={projectSlug} resourceSlug={resourceSlug}
            sibling={nextActivity} prefix="Next Activity >"/>
        </ul>
      </nav>
    </div>
  );

};

