
drop view if exists user_stats_all;
create view user_stats_all as
with map_stats as (
    select
        A1.user_id,
        M.map_id,
        1.0 * SUM(
            case
                when (A1.user_id = M.playerA AND M.outcome = 1)
                  or (A1.user_id = M.playerB AND M.outcome = 0)
                then 1
                else 0
            end
        ) / COUNT(*) as map_win_ratio
    from users A1
    join mecevi M
      on A1.user_id = M.playerA
      or A1.user_id = M.playerB
    group by A1.user_id, M.map_id
),
fav_map_ranked as (
    select
        user_id,
        map_id,
        map_win_ratio,
        ROW_NUMBER() over (
            partition by user_id
            order by map_win_ratio desc, map_id
        ) as ind
    from map_stats
)
    select
        A.username,
        ---------------------------
        A.country,
        --------------------------
        (select H.map_name
         from raw_maps H, fav_map_ranked T
         where T.ind=1 and H.map_id=T.map_id and A.user_id=T.user_id
        ) AS fav_map,
        --------------------------------
       (
        select (
           1.0 * SUM(
            case
                when (AA.user_id = MM.playerA AND MM.outcome = 1)
                  or (AA.user_id = MM.playerB AND MM.outcome = 0)
                then 1
                else 0
            end
        ) / COUNT(*) )
        from users AA join mecevi MM
        on (AA.user_id=MM.playerA or AA.user_id=MM.playerB) and AA.user_id=A.user_id
        and MM.map_id=(select map_id from fav_map_ranked where fav_map_ranked.user_id=A.user_id and fav_map_ranked.ind=1)
        ) as fav_map_win_ratio,
        --------------------------------------
        (
         select sum(S.duration)
         from sessions S
         where A.user_id=S.user_id
         )as total_playtime,
        --------------------------------------
         1.0 * SUM(
            case
                when (A.user_id = M.playerA AND M.outcome = 1)
                  or (A.user_id = M.playerB AND M.outcome = 0)
                then 1
                else 0
            end
        ) / COUNT(*)
     as total_win_ratio,
      --------------------------------------------
    date(A.timestamp, 'unixepoch') as registration_date,
    ---------------------------------------------
    (select 1.0 * count(*) / (select count(*) from sessions S where S.user_id=A.user_id )
      from users AAA join mecevi MMM
        on (AAA.user_id=MMM.playerA or AAA.user_id=MMM.playerB) and AAA.user_id=A.user_id
        )  as avg_matches_per_session
    -------------------------------------------------------------------
from users A
left join mecevi M on A.user_id = M.playerA or A.user_id = M.playerB
group by  A.user_id, A.username, A.country;

------------------------------------------
------------------------------------------
------------------------------------------
------------------------------------------
------------------------------------------
------------------------------------------
------------------------------------------
------------------------------------------
------------------------------------------
------------------------------------------

drop view if exists user_stats_os;
create view user_stats_os as
with map_stats as (
    select
        M.user_id,
        M.device_os,
        M.map_id,
        1.0 * SUM(
            case
                when M.outcome = 1 then 1
                else 0
            end
        ) / COUNT(*) as map_win_ratio
    from user_match_sessions M
    group by M.user_id, M.device_os, M.map_id
),
fav_map_ranked as (
    select
        device_os,
        user_id,
        map_id,
        map_win_ratio,
        ROW_NUMBER() over (
            partition by user_id, device_os
            order by map_win_ratio desc , map_id
        ) as ind
    from map_stats
)
    select
        A.username,

        S.device_os,
        ---------------------------
        A.country,
        --------------------------
        (select H.map_name
         from raw_maps H, fav_map_ranked T
         where T.ind=1 and H.map_id=T.map_id and A.user_id=T.user_id and T.device_os = S.device_os
        ) AS fav_map,
        --------------------------------------
        (
         select sum(SS.duration)
         from sessions SS
         where A.user_id=SS.user_id and SS.device_os=S.device_os
         )as total_playtime,
        --------------------------------------
        (
    select 1.0 * SUM(
        case
            when M.outcome = 1 then 1
            else 0
        end
    ) / COUNT(*)
    from user_match_sessions M
    where M.user_id = A.user_id
      and M.device_os = S.device_os
) as total_win_ratio,
        ----------------------------------
         ( select T.map_win_ratio
        from fav_map_ranked T
        where T.ind = 1
          and T.user_id = A.user_id
          and T.device_os = S.device_os
    ) as fav_map_win_ratio,
      --------------------------------------------
    date(A.timestamp, 'unixepoch') as registration_date,
    ---------------------------------------------
    (select 1.0 * count(*) / (select count(*) from sessions SS where SS.user_id=A.user_id and SS.device_os=S.device_os)
       from user_match_sessions M
        where M.user_id = A.user_id
          and M.device_os = S.device_os) as avg_matches_per_session
    -------------------------------------------------------------------
from users A
left join sessions S on A.user_id = S.user_id
group by A.user_id, S.device_os;

------------------------------------------
------------------------------------------
------------------------------------------
------------------------------------------
------------------------------------------
------------------------------------------
------------------------------------------
------------------------------------------

drop view if exists map_stats;
create view map_stats as
select
    M.map_id,
    datum as date,
    avg(M.trajanje) as avg_playtime,
   (select U.username
    from users U where U.user_id =
    (select M2.user_id
    from user_matches_sa_datumima M2 where M2.map_id=M.map_id and M2.datum<=M.datum
    group by M2.user_id
    order by 1.0 * sum(case when M2.outcome = 1 then 1 else 0 end) / count(*) desc, M2.user_id
    limit 1
    )) as best_player_username,
    count(*) as match_cnt
from mecevi_sa_datumima M
group by M.map_id, M.datum
order by M.datum desc;




