--- Checking what exact process is locking our processes/transactions

SELECT 
  blocking_session_id,
  session_id,
  wait_type,
  wait_time,
  wait_resource
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0;

--- Detailed look at process that is blocking us

SELECT * FROM sys.dm_exec_sessions
WHERE session_id = [blocking_session_id number]
