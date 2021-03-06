select
--DEST_ID, DEST_NAME ,STATUS ,TYPE ,
remote.DESTINATION 
--,DATABASE_MODE ,RECOVERY_MODE ,PROTECTION_MODE
--,STANDBY_LOGFILE_COUNT stdby_logs
--,STANDBY_LOGFILE_ACTIVE
,remote.ARCHIVED_THREAD#,local.applied - remote.applied GAP
--, APPLIED_THREAD#||':'||APPLIED_SEQ# "applied_thr/seq"
from ( select DEST_ID, DESTINATION, ARCHIVED_THREAD#, max(APPLIED_SEQ#) applied
		from V$ARCHIVE_DEST_STATUS 
		where type!='LOCAL' and status!='INACTIVE'
		group by DEST_ID, DESTINATION, ARCHIVED_THREAD#  ) remote
, ( select DEST_ID, DESTINATION, ARCHIVED_THREAD#, max(ARCHIVED_SEQ#) applied
		from V$ARCHIVE_DEST_STATUS 
		where type='LOCAL' and status!='INACTIVE'
		group by DEST_ID, DESTINATION, ARCHIVED_THREAD# ) local
where remote.ARCHIVED_THREAD#=local.ARCHIVED_THREAD#
/
