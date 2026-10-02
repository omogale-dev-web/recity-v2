# RECITY v2 — setup and current status

This is a NEW application. The previous RECITY project has not been changed.

## 1. Enable email-free accounts
In your new Supabase project's Authentication settings, enable anonymous sign-ins. A read-only check confirmed they were disabled when this guide was written. Enable abuse protection before public launch.

## 2. Create the database
Open the new project's SQL editor. Run `supabase/001_initial.sql` once. It creates private report photo storage, user profiles, reports, event history, invitations, offers, collection proof, rewards and AI request limits. The migration has NOT been executed or verified against your database yet.

## 3. Activate your municipal account
Open RECITY and choose Continue on this device. In Profile & help, copy your Account ID. In the NEW project's SQL editor, run the following after replacing the placeholder with your own account ID:

```sql
update public.profiles set role = 'administrator', display_name = 'Omprakash Ogale' where id = 'YOUR_ACCOUNT_ID';
```

Refresh the app. Only perform this for your own trusted account. Do not share sessions or project secrets. Municipal access is not available merely by opening its screen.

## 4. Configure private AI settings
Copy `.env.example` to `.dev.vars` inside this project. Fill the empty Groq and Supabase secret values locally. Do not paste secrets in chat or commit this file. For hosting, set the same values in the provider's secret manager. The Groq vision model is configurable and must be tested with your account.

## 5. Test the real workflow
Create a citizen session in a different browser. Create a collector invitation from your administrator account, using a service area and capabilities. Activate on the collector's browser and turn On duty on. Submit a report with matching area; incoming reports currently default to unknown. Verify it manually, offer to a collector authorized for that category, accept, submit proof and resolve. Verify that the citizen can dispute closure and reward reversals are recorded. This workflow must be tested with real configured services before any reliability claim.

## Current limitations — not a final production release
- Database migration and access policies are authored, not live-tested.
- Groq analysis and guide endpoints require private settings; model performance is untested.
- Hazard score is an experimental rule-based screening indicator, not probability or validated physical risk.
- Report screening is currently manual; automated screening, duplicate detection and dispatch are not implemented.
- Job inbox refreshes while the app is open. Web Push and background reassignment are not implemented.
- Google Maps directions links work; embedded map provider, hotspot view and location-based dispatch remain pending.
- Offline report queue persists files in IndexedDB and retries when the open app regains connectivity. An offline shell and service worker have been added but not yet tested in a deployed browser. Background sync and the collection-proof queue remain pending.
- Recovery/revocation, Marathi translation, comprehensive analytics, production security tests and installability verification remain pending.
- Do not use this build for real municipal operations yet.

## Local development
Use Node.js and the existing package lock. Run `npm run dev` from this folder. The local preview is normally at port 3000. Stop with Ctrl+C in its terminal.

## Checks completed locally
- TypeScript check passed.
- Six decision-policy tests passed.
- Server build passed.
- Home and scan navigation checked in the browser; phone layout inspected at 390 px.
- Missing AI credentials produce an explicit unavailable response, not a fake assessment.
- Supabase settings endpoint returned successfully; anonymous sign-ins were disabled.


## Connection verification update
Groq and Supabase server credentials are now configured locally and passed connection checks. A labelled test session submitted the generated city illustration through the real analysis endpoint: it returned not_waste, no numeric hazard score and no reuse approval; the result was saved and readable by that test session. This is a connection smoke test, not evidence of waste-classification accuracy. Two labelled connection-test accounts were created during diagnosis. Live keys remain only in ignored local settings. Rotate the keys shared in chat before deployment.

