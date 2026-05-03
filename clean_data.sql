
--basic cleaning
DROP view IF EXISTS clean_I;
CREATE VIEW clean_I AS
SELECT id, timestamp, event_type, user_id, event_data
from (
    select
        id,
        timestamp,
        event_type,
        user_id,
        event_data,
        ROW_NUMBER() OVER (
            PARTITION BY id
            ORDER BY timestamp
        ) as ind
    from raw_events
    where event_type in ('registration', 'session_ping', 'match_start', 'match_finish')
      and timestamp is not NULL
      and user_id is not NULL
      and event_data is not NULL
) A
where A.ind = 1;


DROP TABLE IF EXISTS clean_II;
create Table clean_II as
select *
from clean_I
where (
          (
              event_type = 'registration'
              and
              json_extract(event_data, '$.country') is not null
              and
              json_extract(event_data, '$.device_os') in ('iOS', 'Android')
              and
              (
                  json_extract(event_data, '$.username') is not NULL
                  and
                  TRIM(json_extract(event_data, '$.username')) != ''
              )
          )
          or
          (
              event_type = 'session_ping'
              and
              json_extract(event_data, '$.state') in ('started', 'in_progress', 'ended')
              and
              json_extract(event_data, '$.device_os') in ('iOS', 'Android')
          )
          or
          (
              event_type = 'match_start'
              and
              json_extract(event_data, '$.opponent_id') is not null
              and
              json_extract(event_data, '$.opponent_id') != user_id
          )
          or
          (
              event_type = 'match_finish'
              and
              json_extract(event_data, '$.opponent_id') is not null
              and
              json_extract(event_data, '$.opponent_id') != user_id
          )

          );


--uncomplete matc_end which can not be recreated
drop view if exists  falicni_end;
create view falicni_end as
select id
from clean_II A
where event_type='match_finish' and
              (
              (json_extract(event_data, '$.map_id') is null or json_extract(event_data, '$.map_id') not in (select map_id from raw_maps))
              or
              json_extract(event_data, '$.outcome') is null or (json_extract(event_data, '$.outcome') not in (0.5, 1, 0))
              )
    and  not exists (
        select *
        from clean_II B
        where  B.event_type='match_finish' and B.timestamp=A.timestamp
               and B.user_id=json_extract(A.event_data, '$.opponent_id') and json_extract(B.event_data, '$.opponent_id')=A.user_id
               and (json_extract(B.event_data, '$.map_id') in (select map_id from raw_maps)
               and json_extract(B.event_data, '$.outcome') in (0.5, 1, 0))
)
;

--uncomplete match_start which can not be recreated
drop view if exists  falicni_start;
create view falicni_start as
select id
from clean_II A
where event_type='match_start'
      and (
            json_extract(event_data, '$.map_id') is null
                or
            json_extract(event_data, '$.map_id') not in (select map_id from raw_maps)
          )
      and not exists (
            select *
            from clean_II B
            where  B.event_type='match_start' and B.timestamp = A.timestamp
            and B.user_id=json_extract(A.event_data, '$.opponent_id') and json_extract(B.event_data, '$.opponent_id')=A.user_id
            and json_extract(B.event_data, '$.map_id') in (select map_id from raw_maps)
            )
;

--final clean table
DELETE FROM clean_II
where id in (
    select id from falicni_start
    union
    select id from falicni_end
);

