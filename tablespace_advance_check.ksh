#!/bin/ksh
start1=$(date +%s)
mkdir -p tmp && rm -rf tmp/*  >/dev/null 2>&1
sqlplus -s psa/ttipass@$ORACLE_SID <<EOF
col autoextensible for a20
SET FEEDBACK OFF
set termout off
set heading off
set linesize 300
--set markup html on spool on
--spool tbs.txt
select
case 
when autoextensible = 'NO' then case when Pct_used > 90 and Pct_used < 95 then 'WARNING - '
                                 when Pct_used > 95 then 'CRITICAL - '
                                 when Pct_used < 90 then 'OK - '
                            end
							when autoextensible = 'YES' then case when (megs_used/maxsize)*100 > 90 then 'WARNING - '
                                 when (megs_used/maxsize)*100 > 95 then 'CRITICAL - '
                                 when (megs_used/maxsize)*100 < 90 then 'OK - '                           
                            end                                                 
end || ' tablespace ' || ' [ $ORACLE_SID ] ' ||
case when tablespace_name in ('UNDOTBS1','UNDOTBS2','UNDOTBS3','SYSAUX','SYSTEM','TEMP') then '[ Customer ] '
else '[ Teoco ] '
end || tablespace_name ||
case when autoextensible = 'YES' then ' ( autoextensible )'
else   ' ( NOT autoextensible )'
end 
|| ' **  [' ||  megs_free || ' (MB)Free] /['||  megs_used  || ' (MB)Used] ** ['|| Pct_used || '% CURRENT UTILIZATION] '||
case when autoextensible = 'YES' then ' ** ['||round((megs_used/maxsize)*100,2) || '% UTILIZATION of MAXSIZE] / ['|| Maxsize || ' (MB) MAXSIZE]'
else   ' ' end
from
(select
   a.tablespace_name,
   round(a.bytes_alloc / 1024 / 1024, 2) megs_alloc,
   round(nvl(b.bytes_free, 0) / 1024 / 1024, 2) megs_free,
   round((a.bytes_alloc - nvl(b.bytes_free, 0)) / 1024 / 1024, 2) megs_used,
   round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100,2) Pct_Free,
   100 - round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100,2) Pct_used,
   a.autoextensible autoextensible,
   round(maxbytes/1048576,2) Maxsize
   from
   ( select f.tablespace_name, f.autoextensible autoextensible, sum(f.bytes) bytes_alloc,
   sum(decode(f.autoextensible, 'YES',f.maxbytes,'NO', f.bytes)) maxbytes
from
   dba_data_files f
group by
   tablespace_name, autoextensible) a,
(  select
      f.tablespace_name,
      sum(f.bytes) bytes_free
   from
      dba_free_space f
group by
      tablespace_name) b
where
      a.tablespace_name = b.tablespace_name (+)
union
select
   h.tablespace_name,
   round(sum(h.bytes_free + h.bytes_used) / 1048576, 2),
   round(sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / 1048576, 2),
   round(sum(nvl(p.bytes_used, 0))/ 1048576, 2),
   round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) /
   sum(h.bytes_used + h.bytes_free)) * 100,2),
   100 - round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) /
   sum(h.bytes_used + h.bytes_free)) * 100,2),
   t.autoextensible,
   round(max(h.bytes_used + h.bytes_free) / 1048576, 2)
from
   sys.v_\$TEMP_SPACE_HEADER h, sys.v_\$Temp_extent_pool p, dba_temp_files t
where
   p.file_id(+) = h.file_id
and
   p.tablespace_name(+) = h.tablespace_name
and
   h.tablespace_name = t.tablespace_name
group by
   h.tablespace_name, t.autoextensible
ORDER BY 1) ans
where 1=1;
--spool off;
exit
EOF
echo
rm -rf tmp/*  >/dev/null 2>&1
end1=$(date +%s)
echo "Elapsed Time: $(($end1-$start1)) seconds

Thank You"
exit 1
