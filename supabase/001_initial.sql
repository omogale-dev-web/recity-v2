-- RECITY v2. Run once in the NEW project's SQL editor. No original project changes.
begin;
create extension if not exists pgcrypto with schema extensions;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default 'Citizen' check (length(display_name) between 1 and 100),
 role text not null default 'citizen' check(role in ('citizen','collector','administrator')),
 service_area text, capabilities text[] not null default '{}', on_duty boolean not null default false,
 latitude double precision, longitude double precision, location_at timestamptz,
 created_at timestamptz not null default now()
);
create table public.reports (
 id uuid primary key default gen_random_uuid(), client_id uuid not null, citizen_id uuid not null references public.profiles(id),
 description text not null check(length(description) between 3 and 3000), landmark text not null default '',
 latitude double precision not null check(latitude between -90 and 90), longitude double precision not null check(longitude between -180 and 180),
 category text not null default 'unknown' check(category in ('recyclable','organic','electronic','sanitary','hazardous','construction','bulky','animal_remains','mixed','unknown')),
 service_area text not null default 'Unassigned', photo_path text not null,
 status text not null default 'reported' check(status in ('reported','verified','assigned','collected','resolved','blocked','reopened','rejected')),
 collector_id uuid references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), resolved_at timestamptz,
 unique(citizen_id,client_id)
);
create table public.report_events(id bigint generated always as identity primary key, report_id uuid not null references public.reports(id) on delete cascade, actor_id uuid references public.profiles(id), action text not null, note text not null default '',created_at timestamptz not null default now());
create table public.job_offers(id uuid primary key default gen_random_uuid(),report_id uuid not null references public.reports(id),collector_id uuid not null references public.profiles(id),status text not null default 'pending' check(status in('pending','accepted','declined','expired','cancelled')),expires_at timestamptz not null default now()+interval '15 minutes',created_at timestamptz not null default now());
create unique index one_pending_offer on public.job_offers(report_id) where status='pending';
create table public.collection_proof(id uuid primary key default gen_random_uuid(),report_id uuid not null references public.reports(id),collector_id uuid not null references public.profiles(id),photo_path text not null,note text not null default '',created_at timestamptz not null default now());
create table public.collector_invitations(id uuid primary key default gen_random_uuid(),token_hash text unique not null,display_name text not null,service_area text not null,capabilities text[] not null,created_by uuid not null references public.profiles(id),expires_at timestamptz not null default now()+interval '24 hours',used_at timestamptz);
create table public.reward_ledger(id bigint generated always as identity primary key,user_id uuid not null references public.profiles(id),report_id uuid not null references public.reports(id),points integer not null,reason text not null,created_at timestamptz not null default now(),check(points between -1000 and 1000));
create table public.analysis_runs(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id),result jsonb not null,model text not null,policy_version text not null,created_at timestamptz not null default now());
create function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='administrator') $$;
create function public.can_read_report(rid uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.reports r where r.id=rid and (r.citizen_id=auth.uid() or r.collector_id=auth.uid() or public.is_admin() or exists(select 1 from public.job_offers j where j.report_id=r.id and j.collector_id=auth.uid() and j.status='pending' and j.expires_at>now()))) $$;
create function public.create_profile() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id) values(new.id); return new; end $$;
create trigger recity_profile after insert on auth.users for each row execute function public.create_profile();
-- Include any anonymous sessions created before this migration.
insert into public.profiles(id) select id from auth.users on conflict do nothing;
alter table public.profiles enable row level security;
alter table public.reports enable row level security;
alter table public.report_events enable row level security;
alter table public.job_offers enable row level security;
alter table public.collection_proof enable row level security;
alter table public.collector_invitations enable row level security;
alter table public.reward_ledger enable row level security;
alter table public.analysis_runs enable row level security;
create policy profile_read on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
create policy report_read on public.reports for select to authenticated using(public.can_read_report(id));
create policy events_read on public.report_events for select to authenticated using(public.can_read_report(report_id));
create policy offers_read on public.job_offers for select to authenticated using(collector_id=auth.uid() or public.is_admin());
create policy proof_read on public.collection_proof for select to authenticated using(public.can_read_report(report_id));
create policy rewards_read on public.reward_ledger for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy analysis_read on public.analysis_runs for select to authenticated using(user_id=auth.uid());
-- All writes use controlled functions. No browser is allowed to edit role or report status directly.
create function public.save_profile(p_name text,p_on_duty boolean default false) returns void language plpgsql security definer set search_path=public as $$ begin if auth.uid() is null then raise exception 'Authentication required'; end if; update profiles set display_name=left(trim(p_name),100),on_duty=case when role='collector' then p_on_duty else false end where id=auth.uid(); end $$;
create function public.create_report(p_client uuid,p_description text,p_landmark text,p_lat double precision,p_lon double precision,p_category text,p_photo text,p_area text) returns uuid language plpgsql security definer set search_path=public as $$ declare rid uuid; begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if split_part(p_photo,'/',1)<>auth.uid()::text or not exists(select 1 from storage.objects where bucket_id='report-media' and name=p_photo) then raise exception 'Upload your report photo first'; end if;
 select id into rid from reports where citizen_id=auth.uid() and client_id=p_client; if rid is not null then return rid; end if;
 if (select count(*) from reports where citizen_id=auth.uid() and created_at>now()-interval '1 hour')>=10 then raise exception 'Hourly report limit reached'; end if;
 insert into reports(client_id,citizen_id,description,landmark,latitude,longitude,category,photo_path,service_area) values(p_client,auth.uid(),p_description,left(p_landmark,300),p_lat,p_lon,p_category,p_photo,left(coalesce(nullif(trim(p_area),''),'Unassigned'),100)) returning id into rid;
 insert into report_events(report_id,actor_id,action) values(rid,auth.uid(),'reported'); return rid; end $$;
create function public.create_collector_invitation(p_name text,p_area text,p_capabilities text[]) returns text language plpgsql security definer set search_path=public,extensions as $$ declare token text; begin
 if not public.is_admin() then raise exception 'Administrator required'; end if;
 if nullif(trim(p_name),'') is null or nullif(trim(p_area),'') is null or cardinality(p_capabilities)<1 then raise exception 'Name, service area and capability are required'; end if;
 token:=encode(extensions.gen_random_bytes(18),'hex'); insert into collector_invitations(token_hash,display_name,service_area,capabilities,created_by) values(encode(extensions.digest(token,'sha256'),'hex'),left(p_name,100),left(p_area,100),p_capabilities,auth.uid()); return token; end $$;
create function public.activate_collector(p_token text) returns void language plpgsql security definer set search_path=public,extensions as $$ declare inv collector_invitations; begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not exists(select 1 from profiles where id=auth.uid() and role='citizen') then raise exception 'Only a citizen account can activate'; end if;
 select * into inv from collector_invitations where token_hash=encode(extensions.digest(trim(p_token),'sha256'),'hex') and used_at is null and expires_at>now() for update;
 if inv.id is null then raise exception 'Invitation invalid, expired or already used'; end if;
 update profiles set role='collector',display_name=inv.display_name,service_area=inv.service_area,capabilities=inv.capabilities where id=auth.uid(); update collector_invitations set used_at=now() where id=inv.id; end $$;
create function public.offer_job(p_report uuid,p_collector uuid) returns uuid language plpgsql security definer set search_path=public as $$ declare r reports;c profiles;oid uuid;begin
 if not public.is_admin() then raise exception 'Administrator required'; end if;
 select * into r from reports where id=p_report for update;select * into c from profiles where id=p_collector;
 if r.id is null or r.status not in('verified','blocked','reopened') then raise exception 'Report must be verified before assignment';end if;
 if c.id is null or c.role<>'collector' or not c.on_duty or c.service_area<>r.service_area or not(r.category=any(c.capabilities)) then raise exception 'Collector is not eligible for this area and waste category';end if;
 update job_offers set status='cancelled' where report_id=p_report and status='pending';
 insert into job_offers(report_id,collector_id) values(p_report,p_collector) returning id into oid;
 insert into report_events(report_id,actor_id,action) values(p_report,auth.uid(),'job_offered');return oid;end $$;
create function public.respond_offer(p_offer uuid,p_accept boolean) returns void language plpgsql security definer set search_path=public as $$ declare j job_offers; r reports;begin
 select * into j from job_offers where id=p_offer and collector_id=auth.uid() for update;
 if j.id is null or j.status<>'pending' or j.expires_at<=now() then raise exception 'Offer no longer available';end if;
 select * into r from reports where id=j.report_id for update;
 if p_accept and r.status not in('verified','blocked','reopened') then raise exception 'Job no longer assignable';end if;
 update job_offers set status=case when p_accept then 'accepted' else 'declined' end where id=j.id;
 if p_accept then update reports set collector_id=auth.uid(),status='assigned',updated_at=now() where id=j.report_id;end if;
 insert into report_events(report_id,actor_id,action) values(j.report_id,auth.uid(),case when p_accept then 'assigned' else 'offer_declined' end);end $$;
create function public.submit_proof(p_report uuid,p_photo text,p_note text) returns void language plpgsql security definer set search_path=public as $$ declare r reports;begin
 select * into r from reports where id=p_report for update;
 if r.collector_id is distinct from auth.uid() or r.status<>'assigned' then raise exception 'An assigned collector is required';end if;
 if split_part(p_photo,'/',1)<>auth.uid()::text or not exists(select 1 from storage.objects where bucket_id='report-media' and name=p_photo) then raise exception 'Upload collection evidence first';end if;
 insert into collection_proof(report_id,collector_id,photo_path,note) values(p_report,auth.uid(),p_photo,left(p_note,1000));update reports set status='collected',updated_at=now() where id=p_report;insert into report_events(report_id,actor_id,action,note) values(p_report,auth.uid(),'collected',left(p_note,1000));end $$;
create function public.transition_report(p_report uuid,p_action text,p_note text) returns void language plpgsql security definer set search_path=public as $$ declare r reports;begin
 select * into r from reports where id=p_report for update;if r.id is null then raise exception 'Report not found';end if;
 if p_action='reopened' then if r.citizen_id is distinct from auth.uid() or r.status<>'resolved' then raise exception 'Only the reporting citizen may reopen a resolved report';end if;
 elsif p_action='blocked' then if r.collector_id is distinct from auth.uid() or r.status<>'assigned' then raise exception 'Only assigned collector may report a blocker';end if;
 else if not public.is_admin() then raise exception 'Administrator required';end if;
 if not ((p_action='verified' and r.status in('reported','reopened','blocked')) or (p_action='resolved' and r.status='collected') or(p_action='rejected' and r.status='reported')) then raise exception 'Invalid transition';end if;end if;
 if length(trim(p_note))<3 then raise exception 'Explain the decision';end if;
 update reports set status=p_action,updated_at=now(),resolved_at=case when p_action='resolved' then now() else null end where id=p_report;
 insert into report_events(report_id,actor_id,action,note) values(p_report,auth.uid(),p_action,left(p_note,1000));
 if p_action='resolved' then insert into reward_ledger(user_id,report_id,points,reason) values(r.citizen_id,r.id,20,'resolved_report');end if;
 if p_action='reopened' then insert into reward_ledger(user_id,report_id,points,reason) values(r.citizen_id,r.id,-20,'reopened_report');end if;end $$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('report-media','report-media',false,6291456,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy media_upload on storage.objects for insert to authenticated with check(bucket_id='report-media' and (storage.foldername(name))[1]=auth.uid()::text);
create policy media_read on storage.objects for select to authenticated using(bucket_id='report-media' and ((storage.foldername(name))[1]=auth.uid()::text or exists(select 1 from reports r where r.photo_path=name and public.can_read_report(r.id)) or exists(select 1 from collection_proof p where p.photo_path=name and public.can_read_report(p.report_id))));
revoke all on public.profiles,public.reports,public.report_events,public.job_offers,public.collection_proof,public.collector_invitations,public.reward_ledger,public.analysis_runs from anon,authenticated;
grant select on public.profiles,public.reports,public.report_events,public.job_offers,public.collection_proof,public.reward_ledger,public.analysis_runs to authenticated;
revoke execute on function public.is_admin(),public.can_read_report(uuid),public.create_profile(),public.save_profile(text,boolean),public.create_report(uuid,text,text,double precision,double precision,text,text,text),public.create_collector_invitation(text,text,text[]),public.activate_collector(text),public.offer_job(uuid,uuid),public.respond_offer(uuid,boolean),public.submit_proof(uuid,text,text),public.transition_report(uuid,text,text) from public,anon;
grant execute on function public.is_admin(),public.can_read_report(uuid),public.save_profile(text,boolean),public.create_report(uuid,text,text,double precision,double precision,text,text,text),public.create_collector_invitation(text,text,text[]),public.activate_collector(text),public.offer_job(uuid,uuid),public.respond_offer(uuid,boolean),public.submit_proof(uuid,text,text),public.transition_report(uuid,text,text) to authenticated;
create table public.analysis_requests(id bigint generated always as identity primary key,user_id uuid not null references public.profiles(id),created_at timestamptz not null default now());
alter table public.analysis_requests enable row level security;
revoke all on public.analysis_requests from anon,authenticated;
create function public.reserve_analysis(p_user uuid) returns void language plpgsql security definer set search_path=public as $$ begin
 perform pg_advisory_xact_lock(hashtext(p_user::text));
 if (select count(*) from analysis_requests where user_id=p_user and created_at>now()-interval '1 hour')>=15 then raise exception 'Hourly analysis limit reached';end if;
 insert into analysis_requests(user_id) values(p_user);end $$;
revoke execute on function public.reserve_analysis(uuid) from public,anon,authenticated;
grant execute on function public.reserve_analysis(uuid) to service_role;
grant all on public.profiles,public.reports,public.report_events,public.job_offers,public.collection_proof,public.collector_invitations,public.reward_ledger,public.analysis_runs,public.analysis_requests to service_role;
commit;

