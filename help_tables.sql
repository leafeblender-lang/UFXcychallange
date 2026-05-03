--pom table users
drop table if exists users;
create table users as
SELECT
    user_id,
    json_extract(event_data, '$.username') as username,
    json_extract(event_data, '$.country') as country,
    json_extract(event_data, '$.device_os') as device_os,
    timestamp
FROM clean_II
WHERE event_type = 'registration';

--------------------------------------------------------------------------

--pom table sessions
DROP TABLE IF EXISTS sessions;
create table sessions as
WITH pings as (
    select
        user_id,
        timestamp,
        json_extract(event_data, '$.device_os') as device_os,
        LAG(timestamp) over (
            partition by user_id
            order by timestamp
        ) AS prev_session_pings
    from clean_II
    where event_type = 'session_ping'
),
pom as (
    select
        user_id,
        timestamp,
        device_os,
        CASE
            WHEN prev_session_pings is NULL then 1
            WHEN timestamp - prev_session_pings > 120 then 1
            ELSE 0
        END as new_session
    from pings
),
session_groups as (
    select
        user_id,
        timestamp,
        device_os,
        SUM(new_session) over (
            partition by user_id
            order by timestamp
            ROWS UNBOUNDED PRECEDING
        ) as session_group
    from pom
)
select
    ROW_NUMBER() over (order by user_id, MIN(timestamp)) as session_id,
    user_id,
    MIN(device_os) as device_os,
    MIN(timestamp) as session_start,
    MAX(timestamp) as session_end,
    (MAX(timestamp) - MIN(timestamp)) as duration
from session_groups
group by user_id, session_group;

-----------------------------------------------------------------------------------------------------

--reconstruct of incomplete match_starrt
drop view if exists match_start_fix;
create view match_start_fix as
select
    A.id,
    A.user_id,
    json_extract(A.event_data, '$.opponent_id') AS opponent_id,
    coalesce (
    case
        when json_extract(A.event_data,'$.map_id') in (select map_id from raw_maps)
        then json_extract(A.event_data,'$.map_id')
        end,
        json_extract(B.event_data,'$.map_id')
) as map_id,
A.timestamp
from clean_II A left join clean_II B
on B.event_type='match_start'
and A.user_id=json_extract(B.event_data,'$.opponent_id')
and B.user_id=json_extract(A.event_data,'$.opponent_id')
and B.timestamp=A.timestamp
where A.event_type='match_start';

--ensure that player1(user_id) and player2(opponent_id) are always in same lexicographical order
DROP VIEW IF EXISTS match_start_pom;
create view match_start_pom as
select
    id,
    CASE
        WHEN user_id < opponent_id THEN user_id
        ELSE opponent_id
    END as playerA,
    CASE
        WHEN user_id < opponent_id THEN opponent_id
        ELSE user_id
    END as playerB,
    map_id,
    timestamp
from match_start_fix;


--remove duplicate rows that represent same start of a match
DROP VIEW IF EXISTS match_start_noDuplicate;
create view match_start_noDuplicate as
select
    MIN(id) as id,
    playerA,
    playerB,
    map_id,
    timestamp
from match_start_pom
group by
    playerA,
    playerB,
    map_id,
    timestamp;

--assign sequence number to matches so we can determine which one occurred earlier so we can do pairing easier
DROP VIEW IF EXISTS match_start_final;
create view match_start_final as
select
    id,
    playerA,
    playerB,
    map_id,
    timestamp as startTime,
    ROW_NUMBER() OVER (
        partition by
            playerA,
            playerB,
            map_id
        order by timestamp, id
    ) as ind
from match_start_noDuplicate;


--reconstruct of incomplete match_finish
drop view if exists match_finish_fix;
create view match_finish_fix as
select
A.id,
A.user_id,
A.timestamp,
json_extract(A.event_data,'$.opponent_id') as opponent_id,
coalesce(
  case
    when json_extract(A.event_data,'$.map_id') in (select map_id from raw_maps)
    then json_extract(A.event_data,'$.map_id')
    end,
  json_extract(B.event_data,'$.map_id')
) as map_id,
coalesce(
  case
    when json_extract(A.event_data,'$.outcome') in (0,1,0.5)
    then json_extract(A.event_data,'$.outcome')
    end,
    (1-json_extract(B.event_data,'$.outcome'))
) as outcome
from clean_II A left join clean_II B
on B.event_type='match_finish'
and A.user_id=json_extract(B.event_data,'$.opponent_id')
and B.user_id=json_extract(A.event_data,'$.opponent_id')
and B.timestamp=A.timestamp
where A.event_type='match_finish';


--ensure that player1(user_id) and player2(opponent_id) are always in same lexicograpical order
drop view if exists match_finish_pom;
create view match_finish_pom as
select
id,
case
    when user_id<opponent_id then user_id
    else opponent_id
end as playerA,
case
    when user_id<opponent_id then opponent_id
    else user_id
end as playerB,
timestamp,
map_id,
case
    when user_id<opponent_id then outcome
    else (1-outcome)
end as outcome
from match_finish_fix;


--remove duplicate rows that represent same start of match
drop view if exists match_finish_noDuplicate;
create view match_finish_noDuplicate AS
select
    MIN(id) as id,
    playerA,
    playerB,
    map_id,
    timestamp,
    outcome
from match_finish_pom
group by
    playerA,
    playerB,
    map_id,
    timestamp,
    outcome;


--remove match_finish that dont have match_start pair
drop view if exists match_finish_pom2;
create view match_finish_pom2 as
select *
from (
    select
        F.id,
        F.playerA,
        F.playerB,
        F.map_id,
        F.timestamp,
        F.outcome,

        (
            select COUNT(*)
            from match_start_final A
            where A.playerA = F.playerA
              and A.playerB = F.playerB
              and A.map_id = F.map_id
              and A.startTime <= F.timestamp
        ) as starts_so_far,

        (
            select COUNT(*)
            from match_finish_noDuplicate F2
            where F2.playerA = F.playerA
              and F2.playerB = F.playerB
              and F2.map_id = F.map_id
              and (
                    F2.timestamp < F.timestamp
                    or (F2.timestamp = F.timestamp and F2.id <= F.id)
                  )
        ) as finishes_so_far
    from match_finish_noDuplicate F
)
where finishes_so_far <= starts_so_far;

--vrsimo numeraciju
drop view if exists match_pomm;
create view match_pomm as
select
    id,
    playerA,
    playerB,
    map_id,
    timestamp as finishTime,
    outcome,
    ROW_NUMBER() over (
        partition by
            playerA,
            playerB,
            map_id
        order by timestamp, id
    ) as ind
from match_finish_pom2;


--final match table
drop table if exists mecevi;
create table mecevi as
select
    A.playerA,
    A.playerB,
    A.map_id,
    A.startTime as startTime,
    B.finishTime as finishTime,
    B.outcome
from match_start_final A join match_pomm B
on A.playerA=B.playerA
and A.playerB=B.playerB
and A.map_id=b.map_id
and A.ind=B.ind;




--match with date
drop table if exists mecevi_sa_datumima;
create table mecevi_sa_datumima as
select
playerA,
playerB,
map_id,
date(finishTime,'unixepoch') as datum,
finishTime - startTime as trajanje,
outcome
from mecevi;

--matches for each player
drop table if exists user_matches;
create table user_matches as
select
    playerA as user_id,
    playerB as opponent_id,
    map_id,
    startTime,
    finishTime,
    outcome
from mecevi

union all

select
    playerB as user_id,
    playerA as opponent_id,
    map_id,
    startTime,
    finishTime,
    case
        when outcome = 1 then 0
        when outcome = 0 then 1
        else 0.5
    end as outcome
from mecevi;

--match with date for each player
drop table if exists user_matches_sa_datumima;
create table user_matches_sa_datumima as
select
    user_id,
    opponent_id,
    map_id,
    date(finishTime,'unixepoch') as datum,
    outcome
from  user_matches;


--mecevi po sesijama i operativnom sis
drop table if exists user_match_sessions;
create table user_match_sessions as
select
    A.user_id,
    A.opponent_id,
    A.map_id,
    A.startTime,
    A.finishTime,
    A.outcome,
    S.session_id,
    S.device_os
from user_matches A
join sessions S
    on S.user_id = A.user_id
   and A.finishTime >= S.session_start and A.finishTime <= S.session_end;
-----------------------------------------------------------------------------------

