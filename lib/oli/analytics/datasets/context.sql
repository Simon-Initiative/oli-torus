SELECT jsonb_build_object(
           'dataset_name', (SELECT slug FROM projects WHERE id = ?) || '-' || substring(md5(random()::text) from 1 for 10),
           'skill_titles', (
               SELECT jsonb_object_agg(r.resource_id::text, r.title)
               FROM published_resources pr
               JOIN publications pub ON pub.id = pr.publication_id
               JOIN projects p ON p.id = pub.project_id
               JOIN revisions r ON r.id = pr.revision_id
               WHERE p.id = ? AND pub.published IS NULL AND r.resource_type_id = 4
           ),
           'hierarchy', (
               SELECT jsonb_object_agg(r.resource_id::text, jsonb_build_object(
                          'title', r.title,
                          'graded', r.graded,
                          'children', r.children
                      ))
               FROM published_resources pr
               JOIN publications pub ON pub.id = pr.publication_id
               JOIN projects p ON p.id = pub.project_id
               JOIN revisions r ON r.id = pr.revision_id
               WHERE p.id = ? AND pub.published IS NULL AND (r.resource_type_id = 1 OR r.resource_type_id = 2)
           ),
           'activities', (
               SELECT jsonb_object_agg(r.resource_id::text, jsonb_build_object(
                          'choices', r.content->'choices',
                          'type', a.slug,
                          'parts', (
                              SELECT jsonb_agg(
                                         jsonb_build_object(
                                             'id', part->>'id',
                                             'hints', part->'hints'
                                         )
                                     )
                              FROM jsonb_array_elements(r.content->'authoring'->'parts') AS part
                          )
                      ))
               FROM published_resources pr
               JOIN publications pub ON pub.id = pr.publication_id
               JOIN projects p ON p.id = pub.project_id
               JOIN revisions r ON r.id = pr.revision_id
               JOIN activity_registrations a ON a.id = r.activity_type_id
               WHERE p.id = ? AND pub.published IS NULL AND r.resource_type_id = 3
           )
       ) AS result;
