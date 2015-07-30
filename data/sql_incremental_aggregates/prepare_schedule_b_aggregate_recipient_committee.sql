-- Create initial aggregate
drop table if exists ofec_sched_b_aggregate_recipient_id;
create table ofec_sched_b_aggregate_recipient_id as
select
    cmte_id,
    rpt_yr + rpt_yr % 2 as cycle,
    recipient_cmte_id,
    max(recipient_nm) as recipient_nm,
    sum(disb_amt) as total,
    count(disb_amt) as count
from sched_b
where rpt_yr >= :START_YEAR_ITEMIZED
and disb_amt is not null
and (memo_cd != 'X' or memo_cd is null)
and recipient_cmte_id is not null
group by cmte_id, cycle, recipient_cmte_id
;

-- Create indices on aggregate
create index on ofec_sched_b_aggregate_recipient_id (cmte_id);
create index on ofec_sched_b_aggregate_recipient_id (cycle);
create index on ofec_sched_b_aggregate_recipient_id (recipient_cmte_id);
create index on ofec_sched_b_aggregate_recipient_id (total);
create index on ofec_sched_b_aggregate_recipient_id (count);
