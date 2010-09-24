-- run this aggregator as often as you want, and it will update a stats table.  

set @sprint_custom_field_id = 1;
set @storypoints_custom_field_id = 2;
set @qa_custom_field_id = 24;
-- get string version of date 2 months ago.. don't pull data older than that.
set @old_sprint_string = date_format(date_sub(current_date(), interval 2 month), "%Y.%m.%d");

create table if not exists quickstats_bug_snapshots (
  snapshot_date date,
  sprint varchar(20),
  count_all int(4),
  count_open int(4),
  count_pending int(4),
  count_invalid int(4),
  count_complete int(4),
  count_verified_invalid int(4),
  count_duplicate int(4),
  count_wont_fix int(4),
  count_priority_critical_open int(4),
  count_priority_high_open int(4),
  count_priority_medium_open int(4),
  count_priority_low_open int(4),
  count_priority_rainy_day_open int(4),
  count_priority_unprioritized_open int(4),
  updated_at timestamp,
  KEY `idx_quickstats_bug_snapshots_snapshot_date` (`snapshot_date`),
  KEY `idx_quickstats_bug_snapshots_sprint` (`sprint`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


delete from quickstats_bug_snapshots where snapshot_date = current_date();


-- trackers are 1:Bug, 7:Usability
insert into quickstats_bug_snapshots (snapshot_date,
  sprint,
  count_all,
  count_open,
  count_pending,
  count_invalid,
  count_complete,
  count_verified_invalid,
  count_duplicate,
  count_wont_fix,
  count_priority_critical_open,
  count_priority_high_open,
  count_priority_medium_open,
  count_priority_low_open,
  count_priority_rainy_day_open,
  count_priority_unprioritized_open,
  updated_at)
select
  current_date() as snapshot_date,
  cv_sprint.value,
  sum(1) as count_total,
  sum(case when i.status_id in (1) then 1 else 0 end) as count_open,
  sum(case when i.status_id in (3) then 1 else 0 end) as count_pending,
  sum(case when i.status_id in (8) then 1 else 0 end) as count_invalid,
  sum(case when i.status_id in (12) then 1 else 0 end) as count_complete,
  sum(case when i.status_id in (13) then 1 else 0 end) as count_verified_invalid,
  sum(case when i.status_id in (14) then 1 else 0 end) as count_duplicate,
  sum(case when i.status_id in (11) then 1 else 0 end) as count_wont_fix,
  sum(case when st.is_closed = 0 and en.name = 'Critical' then 1 else 0 end) as count_priority_critical_open,
  sum(case when st.is_closed = 0 and en.name = 'High' then 1 else 0 end) as count_priority_high_open,
  sum(case when st.is_closed = 0 and en.name = 'Medium' then 1 else 0 end) as count_priority_medium_open,
  sum(case when st.is_closed = 0 and en.name = 'Low' then 1 else 0 end) as count_priority_low_open,
  sum(case when st.is_closed = 0 and en.name = 'Rainy Day' then 1 else 0 end) as count_priority_rainy_day_open,
  sum(case when st.is_closed = 0 and en.name = 'Unprioritized' then 1 else 0 end) as count_priority_unprioritized_open,
  now()
from 
  issues i 
  left join issue_statuses st on i.status_id = st.id
  left join enumerations en on i.priority_id = en.id and en.type = 'IssuePriority'
  left join custom_values cv_sprint on i.id = cv_sprint.customized_id and 
     cv_sprint.customized_type = 'Issue' and cv_sprint.custom_field_id = @sprint_custom_field_id
  left join custom_values cv_qa on i.id = cv_qa.customized_id and 
     cv_qa.customized_type = 'Issue' and cv_qa.custom_field_id = @qa_custom_field_id
where 
  i.tracker_id in (1, 7) and
  cv_sprint.value is not null and cv_sprint.value > @old_sprint_string
group by
  cv_sprint.value;