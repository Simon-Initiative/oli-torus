import React from 'react';

interface Props {
  objectives: string[];
}

export const LearningObjectiveList: React.FC<Props> = ({ objectives }) => {
  if (objectives.length === 0) {
    return null;
  }

  return (
    <section className="flex flex-col gap-3 self-stretch">
      {objectives.map((objective, index) => (
        <div key={`${objective}-${index}`} className="flex items-baseline gap-2 min-w-0">
          <div className="shrink-0 whitespace-nowrap font-open-sans text-[12px] font-bold uppercase leading-[12px] tracking-normal text-Text-text-low-alpha">
            LO
          </div>
          <div className="min-w-0 flex-1 font-open-sans text-[14px] font-normal leading-[16px] tracking-normal text-Text-text-high">
            {objective}
          </div>
        </div>
      ))}
    </section>
  );
};
