-- Reconstructs the v0.33.0 UpGrade style outcome tuple from section-wide raw outcomes and the most
-- recent assignment/exposure evidence known at evaluation time. Raw values remain unchanged;
-- correctness applies the historical zero/missing/invalid-division fallback only in this query.
--
-- Required ClickHouse parameters:
--   section_id UInt64
--   evidence_from_timestamp DateTime64(3) (experiment/analysis evidence horizon)
--   from_timestamp DateTime64(3)
--   to_timestamp DateTime64(3)
SELECT
    raw.participant_id AS enrollment_id,
    evidence.selected_condition_code AS condition,
    raw.timestamp AS timestamp,
    if(
        isNull(raw.score)
        OR isNull(raw.out_of)
        OR raw.score = 0
        OR raw.out_of = 0,
        toFloat64(0),
        ifNotFinite(raw.score / raw.out_of, toFloat64(0))
    ) AS correctness
FROM
(
    SELECT
        assumeNotNull(section_id) AS raw_section_id,
        assumeNotNull(project_id) AS raw_project_id,
        assumeNotNull(enrollment_id) AS participant_id,
        timestamp,
        score,
        out_of,
        event_hash
    FROM raw_events
    WHERE section_id = {section_id:UInt64}
      AND event_type = 'activity_attempt'
      AND verb_id = 'http://adlnet.gov/expapi/verbs/evaluated'
      AND timestamp >= {from_timestamp:DateTime64(3)}
      AND timestamp < {to_timestamp:DateTime64(3)}
      AND enrollment_id IS NOT NULL
      AND project_id IS NOT NULL
    ORDER BY raw_section_id, raw_project_id, participant_id, timestamp
) AS raw
ASOF LEFT JOIN
(
    SELECT
        assumeNotNull(section_id) AS evidence_section_id,
        assumeNotNull(project_id) AS evidence_project_id,
        assumeNotNull(enrollment_id) AS participant_id,
        timestamp,
        argMax(condition_code, tuple(event_version, attribution_hash)) AS selected_condition_code
    FROM experiment_attributions
    WHERE section_id = {section_id:UInt64}
      AND attribution_type = 'assignment'
      AND enrollment_id IS NOT NULL
      AND project_id IS NOT NULL
      AND condition_code IS NOT NULL
      AND timestamp >= {evidence_from_timestamp:DateTime64(3)}
      AND timestamp <= {to_timestamp:DateTime64(3)}
    GROUP BY evidence_section_id, evidence_project_id, participant_id, timestamp
    ORDER BY evidence_section_id, evidence_project_id, participant_id, timestamp
) AS evidence
ON raw.raw_section_id = evidence.evidence_section_id
AND raw.raw_project_id = evidence.evidence_project_id
AND raw.participant_id = evidence.participant_id
AND raw.timestamp >= evidence.timestamp
WHERE evidence.selected_condition_code IS NOT NULL
ORDER BY raw.participant_id, raw.timestamp, raw.event_hash;
