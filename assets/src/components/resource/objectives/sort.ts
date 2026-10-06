import * as Immutable from 'immutable';
import { Objective } from 'data/content/objective';

/**
 * Takes an array of objectives and arranges them in a list so that child
 * objectives immediately follow their parent.
 *
 * @param objectives an array of objectives to arrange
 * @returns the arranged objectives as an immutable list
 */
export function arrangeObjectives(objectives: Objective[]): Immutable.List<Objective> {
  // First, deduplicate objectives by id
  // This ensures each objective is processed exactly once, preventing duplicates in the final list
  const byId = objectives.reduce((m: any, o: any) => {
    // Keep only the first occurrence of each id
    if (!m[o.id]) {
      m[o.id] = o;
    }
    return m;
  }, {});

  // Get unique objectives from the byId map
  const uniqueObjectives = Object.values(byId) as Objective[];

  // Identify which objectives are children (have at least one parent)
  const childIds = new Set<number>();
  uniqueObjectives.forEach((o) => {
    if (o.parentIds !== null && o.parentIds.length > 0) {
      childIds.add(o.id);
    }
  });

  // Build parent -> children mapping
  // Each child should appear under only its FIRST parent to avoid duplicates
  const bucketed: { [key: number]: number[] } = {};
  const childAssigned = new Set<number>(); // Track which children have been assigned to a parent

  uniqueObjectives.forEach((o) => {
    // Initialize top-level objectives (those that are not children of anyone)
    if (!childIds.has(o.id)) {
      if (bucketed[o.id] === undefined) {
        bucketed[o.id] = [];
      }
    }

    // Assign children to their first available parent
    if (o.parentIds !== null && o.parentIds.length > 0) {
      // Find the first parent that exists in byId
      for (const parentId of o.parentIds) {
        if (byId[parentId] !== undefined && !childAssigned.has(o.id)) {
          // Initialize parent's bucket if needed
          if (bucketed[parentId] === undefined) {
            bucketed[parentId] = [];
          }
          // Add child only if not already added
          if (!bucketed[parentId].includes(o.id)) {
            bucketed[parentId].push(o.id);
            childAssigned.add(o.id); // Mark as assigned
          }
          break; // Stop after assigning to first parent to avoid duplicates
        }
      }
    }
  });

  // Handle orphaned children: children whose parents don't exist in the list
  // These should appear as top-level objectives
  uniqueObjectives.forEach((o) => {
    if (childIds.has(o.id) && !childAssigned.has(o.id)) {
      // This is a child that couldn't be assigned to any parent
      // Add it as a top-level objective
      if (bucketed[o.id] === undefined) {
        bucketed[o.id] = [];
      }
    }
  });

  // Create ordered list: each parent followed by its children
  const inOrder = Object.keys(bucketed).reduce((all: any, key: any) => {
    const parentId = parseInt(key);
    const parentWithChildren = [byId[parentId], ...bucketed[parentId].map((k: any) => byId[k])];
    return [...all, ...parentWithChildren];
  }, []);

  return Immutable.List<Objective>(inOrder);
}
