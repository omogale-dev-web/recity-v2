# RECITY v2

RECITY is a civic-tech Progressive Web App for waste identification, safe handling guidance, reuse instructions, citizen reporting, and municipal collection workflows.

## Current workspaces

- **Citizen:** scan waste, receive category and estimated hazard guidance, create reports, save offline drafts, track report progress, and follow detailed written reuse instructions.
- **Collector:** receive assigned work, view the confirmed waste location and landmark, update collection status, and upload collection proof.
- **Municipal:** monitor reports, manage collectors, assign work, review evidence, and resolve reports.

## Technology

- Next.js and TypeScript
- Supabase for anonymous sessions, database, storage, and live data
- Groq vision models through protected server endpoints
- Progressive Web App foundations for installability and offline reporting

## Local setup

1. Install dependencies with `npm install`.
2. Copy `.env.example` to `.env.local`.
3. Add the required environment values locally. Never commit secret keys.
4. Apply `supabase/001_initial.sql` to a separate Supabase project.
5. Enable anonymous sign-ins in Supabase Authentication.
6. Start the app with `npm run dev`.

## Validation

```text
npm run build
npm run test:policies
```

## Security

The browser receives only the Supabase project URL and publishable key. Groq and Supabase secret keys are used only by server routes and must be configured in local or hosting environment variables.

## Project status

This repository contains the competition build in active development. Web Push, automatic dispatch, Marathi localization, embedded maps, account recovery, and broad AI accuracy evaluation remain planned work.
