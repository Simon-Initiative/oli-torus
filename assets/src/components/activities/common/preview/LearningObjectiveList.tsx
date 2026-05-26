import React from 'react';

interface Props {
  objectives: string[];
}

export const LearningObjectiveList: React.FC<Props> = ({ objectives }) => {
  if (objectives.length === 0) {
    return null;
  }

  return (
    <section className="self-stretch">
      <ul aria-label="Learning objectives" className="m-0 flex list-none flex-col gap-3 p-0">
        {objectives.map((objective, index) => (
          <li key={`${objective}-${index}`} className="flex min-w-0 items-baseline gap-2">
            <div
              aria-hidden="true"
              className="shrink-0 whitespace-nowrap font-open-sans text-[12px] font-bold uppercase leading-[12px] tracking-normal text-Text-text-low-alpha"
            >
              LO
            </div>
            <span className="sr-only">Learning objective</span>
            <div className="min-w-0 flex-1 font-open-sans text-[14px] font-normal leading-[16px] tracking-normal text-Text-text-high">
              {objective}
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
};
