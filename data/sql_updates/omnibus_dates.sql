-- Trying to make the names flow together as best as possible
-- To keep the titles concise states are abbreviated as multi state if there is more than one
-- Like:
    -- FL House General Election
    -- NH DEM Convention
    -- General Election Multi-state
create or replace function generate_election_title(trc_election_type_id text, office_sought text, contest text[], party text)
returns text as $$
    begin
        return case
        when array_length(contest, 1) > 1 then array_to_string(
            array[
                party,
                office_sought,
                expand_election_type(trc_election_type_id),
                'Multi-state'::text
            ], ' ')
        else array_to_string(
            array[
                array_to_string(contest, ', '),
                party,
                office_sought,
                expand_election_type(trc_election_type_id)
        ], ' ')
        end;
    end
$$ language plpgsql;


-- Not all report types are on dimreporttype, so for the reports to all have
-- titles, I am adding a case. Ideally, we would want the right mapping,
-- that is one of the things we have asked for.
create or replace function name_reports(office_sought text, report_type text, rpt_tp_desc text, election_state text[])
returns text as $$
    begin
        return case
            when rpt_tp_desc is null and array_length(election_state, 1) > 1 then
                array_to_string(
                array[
                    expand_office_description(office_sought),
                    report_type,
                    'Report Multi-state'
                ], ' ')
            when rpt_tp_desc is null then
                array_to_string(
                array[
                    array_to_string(election_state, ', '),
                    expand_office_description(office_sought),
                    report_type
                ], ' ')
            when array_length(election_state, 1) > 1 then array_to_string(
                array[
                    expand_office_description(office_sought),
                    rpt_tp_desc,
                    'Report Multi-state'
                ], ' ')
            else
                array_to_string(
                array[
                    array_to_string(election_state, ', '),
                    expand_office_description(office_sought),
                    rpt_tp_desc
                ], ' ')
        end;
    end
$$ language plpgsql;


--Descriptions and summaries are repetitive, so we are trying to only show the descriptions in some places, That works for most things except court cases, advisory opinions and conferences.
create or replace function describe_cal_event(event_name text, summary text, description text)
returns text as $$
    begin
        return case
            when event_name in ('Litigation', 'AOs and Rules', 'Conferences') then
                summary || description
            else
                description
        end;
    end
$$ language plpgsql;


drop table if exists ofec_omnibus_dates_tmp;
create table ofec_omnibus_dates_tmp as
with elections_raw as(
    select
        *,
        case
            when office_sought = 'H' and election_district != ' ' then array_to_string(
                array[
                    election_state,
                    election_district
                ], '-')
            else election_state
        end as contest
    from
        trc_election
    where
        trc_election_status_id = 1
), elections as (
    select
        'election'::text as category,
        generate_election_title(
            trc_election_type_id::text,
            expand_office_description(office_sought::text),
            array_agg(contest order by contest)::text[],
            dp.party_affiliation_desc::text
        ) as description,
        array_to_string(array[
                dp.party_affiliation_desc::text,
                expand_office_description(office_sought::text),
                expand_election_type(trc_election_type_id::text),
                array_to_string(array_agg(contest order by contest)::text[], ', ')
        ], ' ') as summary,
        array_agg(election_state order by election_state)::text[] as states,
        null::text as location,
        election_date::timestamp as start_date,
        null::timestamp as end_date,
        null::text as url
    from elections_raw
        left join dimparty dp on elections_raw.election_party = dp.party_affiliation
    group by
        contest,
        office_sought,
        election_date,
        dp.party_affiliation_desc,
        trc_election_type_id
), reports_raw as (
    select * from trc_report_due_date reports
    left join dimreporttype on reports.report_type = dimreporttype.rpt_tp
    left join elections_raw using (trc_election_id)
    where coalesce(trc_election_status_id, 1) = 1
), reports as (
    select
        'report-' || report_type as category,
        clean_report(
            name_reports(office_sought::text, report_type::text, rpt_tp_desc::text, array_agg(election_state)::text[])
        ) as description,
        array_to_string(array[
            expand_office_description(office_sought::text),
            clean_report(rpt_tp_desc::text),
            'Due, Report (',
            report_type::text,
            ') ',
            array_to_string(array_agg(election_state order by election_state)::text[], ', ')
        ], ' ') as summary,
        array_agg(election_state)::text[] as states,
        null::text as location,
        due_date::timestamp as start_date,
        null::timestamp as end_date,
        null::text as url
    from reports_raw
    group by
        report_type,
        rpt_tp_desc,
        due_date,
        office_sought
), other as (
    select distinct on (category_name, event_name, description, location, start_date, end_date)
        category_name::text as category,
        event_name::text as summary,
        describe_cal_event(category_name::text, event_name::text, description::text) as description,
        null::text[] as states,
        location::text,
        start_date,
        end_date,
        url
    from cal_event
    join cal_event_category using (cal_event_id)
    join cal_category using (cal_category_id)
    where
        category_name not in ('Election Dates', 'Reporting Deadlines', 'Quarterly', 'Monthly', 'Pre and Post-Elections') and
        active = 'Y'
), combined as (
    select * from elections
    union all
    select * from reports
    union all
    select * from other
)
select
    row_number() over () as idx,
    combined.*,
    to_tsvector(summary) as summary_text,
    to_tsvector(description) as description_text
from combined
;

create unique index on ofec_omnibus_dates_tmp (idx);

create index on ofec_omnibus_dates_tmp (category);
create index on ofec_omnibus_dates_tmp (location);
create index on ofec_omnibus_dates_tmp (start_date);
create index on ofec_omnibus_dates_tmp (end_date);

create index on ofec_omnibus_dates_tmp using gin (states);
create index on ofec_omnibus_dates_tmp using gin (summary_text);
create index on ofec_omnibus_dates_tmp using gin (description_text);

drop table if exists ofec_omnibus_dates;
alter table ofec_omnibus_dates_tmp rename to ofec_omnibus_dates;
