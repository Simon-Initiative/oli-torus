import React from 'react';

interface Props {
  objectives: string[];
}

export const LearningObjectiveList: React.FC<Props> = ({ objectives }) => {
  if (objectives.length === 0) {
    return null;
  }

  return (
    <section className="flex flex-col gap-2 border-t border-gray-200 pt-4">
      <div className="text-xs font-semibold uppercase tracking-wide text-gray-500">
        Learning Objectives
      </div>
      <ul className="mb-0 flex flex-col gap-2 pl-4 text-sm text-gray-700">
        {objectives.map((objective) => (
          <li key={objective}>{objective}</li>
        ))}
      </ul>
    </section>
  );
};
