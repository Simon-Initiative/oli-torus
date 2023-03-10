# Running Upgrade in a Dev Env

These instructions will set up a development environment
for the Upgrade A/B testing platform, paired with your local Torus dev env.

1. Clone our fork at https://github.com/Simon-Initiative/UpGrade
2. In `backend/packages/Upgrade` execute `yarn install`
3. Create a `.env` in that directory from the contents of `.env.example` from `guides/upgrade/.env.example`
4. In your Postgres, manually create a new database `upgrade`
5. Executing `npm run dev` should populate the database.  Subsequent executions will fail until you comment out line 83 of `backend/packages/Upgrade/src/loaders/typeormLoader.ts`
6. From `frontend` directory, run `yarn install`
7. From `frontend` directtory, run `npm run start`

You will also need to specify Torus `.env` variables:

```
UPGRADE_EXPERIMENT_PROVIDER_URL=http://localhost:3030
UPGRADE_EXPERIMENT_USER_URL=http://localhost:4200
```



