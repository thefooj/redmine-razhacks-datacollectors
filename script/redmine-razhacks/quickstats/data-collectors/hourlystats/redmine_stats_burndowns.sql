-- run this aggregator as often as you want, and it will update a stats table.  

set @sprint_custom_field_id = 1;
set @storypoints_custom_field_id = 2;
set @qa_custom_field_id = 24;
-- get string version of date 2 months ago.. don't pull data older than that.
set @old_sprint_string = date_format(date_sub(current_date(), interval 2 month), "%Y.%m.%d");

create table if not exists quickstats_story_snapshots (
  snapshot_date datetime,
  sprint varchar(20),
  sum_total int(4),
  sum_open int(4),
  sum_pending int(4),
  sum_complete int(4),
  sum_pending_and_qa_needed int(4),
  sum_pending_and_qa_succeeded int(4),
  sum_pending_and_qa_failed int(4),
  sum_pending_and_qa_done int(4),
  sum_pending_and_qa_not_needed int(4),
  KEY `idx_quickstats_story_snapshots_snapshot_date` (`snapshot_date`),
  KEY `idx_quickstats_story_snapshots_sprint` (`sprint`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


delete from quickstats_story_snapshots where snapshot_date = current_date();


-- trackers are 2:Story, 4:Systems, 5:TechDebt, 8:Research
insert into quickstats_story_snapshots (snapshot_date, sprint, sum_total, sum_open, sum_pending, sum_complete, 
  sum_pending_and_qa_needed, sum_pending_and_qa_succeeded, sum_pending_and_qa_failed, sum_pending_and_qa_done, sum_pending_and_qa_not_needed)
select
  current_date() as snapshot_date,
  cv_sprint.value,
  sum(convert(cv_spoints.value, unsigned integer)) as sum_total,
  sum(case when i.status_id in (1) then convert(cv_spoints.value, unsigned integer) else 0 end) as sum_open,
  sum(case when i.status_id in (3) then convert(cv_spoints.value, unsigned integer) else 0 end) as sum_pending,
  sum(case when i.status_id in (11) then convert(cv_spoints.value, unsigned integer) else 0 end) as sum_complete,
  sum(case when i.status_id in (3) and cv_qa.value in ('Needed') then convert(cv_spoints.value, unsigned integer) else 0 end) as sum_pending_and_qa_needed,
  sum(case when i.status_id in (3) and cv_qa.value in ('Succeeded') then convert(cv_spoints.value, unsigned integer) else 0 end) as sum_pending_and_qa_succeeded,
  sum(case when i.status_id in (3) and cv_qa.value in ('Failed') then convert(cv_spoints.value, unsigned integer) else 0 end) as sum_pending_and_qa_failed,
  sum(case when i.status_id in (3) and cv_qa.value in ('Succeeded', 'Failed') then convert(cv_spoints.value, unsigned integer) else 0 end) as sum_pending_and_qa_done,
  sum(case when i.status_id in (3) and cv_qa.value in ('Not Needed') then convert(cv_spoints.value, unsigned integer) else 0 end) as sum_pending_and_qa_not_needed
from 
  issues i 
  left join custom_values cv_sprint on i.id = cv_sprint.customized_id and 
     cv_sprint.customized_type = 'Issue' and cv_sprint.custom_field_id = @sprint_custom_field_id
  left join custom_values cv_qa on i.id = cv_qa.customized_id and 
     cv_qa.customized_type = 'Issue' and cv_qa.custom_field_id = @qa_custom_field_id
  left join custom_values cv_spoints on i.id = cv_spoints.customized_id and 
     cv_spoints.customized_type = 'Issue' and cv_spoints.custom_field_id = @storypoints_custom_field_id
where 
  i.tracker_id in (2, 4, 5, 8) and
  cv_sprint.value is not null and cv_sprint.value > @old_sprint_string
group by
  cv_sprint.value;