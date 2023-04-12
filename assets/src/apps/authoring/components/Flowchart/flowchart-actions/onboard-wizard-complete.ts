import { ApplicationMode } from '../../../store/app/slice';
import { savePage } from '../../../store/page/actions/savePage';
import { edit } from '../../../../../data/persistence/resource';
import { PageContent } from '../../../../../data/content/resource';
import { cloneT } from '../../../../../utils/common';
import { acquireLock } from '../../../../../data/persistence/lock';

/**
 * Logic for applying the onboarding wizard.
 * This gets called BEFORE initialize from context, so you can't pull stuff from the state.
 */

export const onboardWizardComplete = async (
  title: string,
  projectSlug: string,
  revisionSlug: string,
  appMode: ApplicationMode,
  pageContent: PageContent,
) => {
  const content = cloneT(pageContent);
  content.custom = {
    contentMode: appMode,
    defaultScreenHeight: 540,
    defaultScreenWidth: 1000,
    enableHistory: appMode === 'flowchart',
    maxScore: 0,
    themeId: 'torus-default-light',
    totalScore: 0,
  };

  content.additionalStylesheets = [
    appMode === 'flowchart'
      ? '/css/delivery_adaptive_themes_flowchart.css'
      : '/css/delivery_adaptive_themes_default_light.css',
  ];
  try {
    const lock = await acquireLock(projectSlug, revisionSlug);
    if (lock.type !== 'acquired') {
      throw new Error('Could not acquire lock');
    }
    const saveResult = await edit(
      projectSlug,
      revisionSlug,
      {
        title,
        objectives: { attached: [] },
        content,
        releaseLock: true,
      },
      true,
    );
    const { type } = saveResult;
    if (type !== 'success') {
      throw new Error('Could not save page');
    }
    const { revision_slug } = saveResult;
    window.location.href = `./${revision_slug}`;
  } catch (e) {
    console.error(e);
    throw e;
  }
};
