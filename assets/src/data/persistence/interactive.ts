import { InteractiveModelSchema } from 'components/activities/interactive/schema';
import { ObjectiveMap } from 'data/content/activity';
import { makeRequest } from './common';

export interface InteractiveBuildResponse {
  build: { id: string; status: string; error: string | null; transcript?: string } | null;
  activity?: { model: InteractiveModelSchema; objectives: ObjectiveMap };
}

const path = (project: string, activity: number) =>
  `/interactives/${encodeURIComponent(project)}/${activity}/builds`;

/** Starts an authorized background build using the current generation inputs and edit lock. */
export function startInteractiveBuild(
  project: string,
  activity: number,
  lockId: number,
  authoring: InteractiveModelSchema['authoring'],
): Promise<InteractiveBuildResponse> {
  return makeRequest<InteractiveBuildResponse>({
    method: 'POST',
    url: path(project, activity),
    body: JSON.stringify({
      lockId,
      prompt: authoring.prompt,
      revisionPrompt: authoring.revision_prompt,
      selectedSkillIds: authoring.selectedSkillIds,
      model: authoring.model ?? 'gpt-6-astra',
      reasoning: authoring.reasoning ?? 'medium',
    }),
  }) as Promise<InteractiveBuildResponse>;
}

/** Fetches the latest build, allowing an authoring page to resume observation after reload. */
export function getInteractiveBuild(
  project: string,
  activity: number,
): Promise<InteractiveBuildResponse> {
  return makeRequest<InteractiveBuildResponse>({
    url: path(project, activity),
  }) as Promise<InteractiveBuildResponse>;
}

/** Cancels exactly one authorized build/revision; pending provider cleanup stays visible. */
export function cancelInteractiveBuild(
  project: string,
  activity: number,
  buildId: string,
): Promise<InteractiveBuildResponse> {
  return makeRequest<InteractiveBuildResponse>({
    method: 'POST',
    url: `${path(project, activity)}/${encodeURIComponent(buildId)}/cancel`,
    body: JSON.stringify({ version: 1 }),
  }) as Promise<InteractiveBuildResponse>;
}
