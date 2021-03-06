CREATE OR REPLACE FUNCTION cron.Register(
_Function          regprocedure,
_Processes         integer     DEFAULT 1,
_Concurrent        boolean     DEFAULT TRUE,
_Enabled           boolean     DEFAULT TRUE,
_RunIfWaiting      boolean     DEFAULT FALSE,
_RetryOnError      interval    DEFAULT NULL,
_RandomInterval    boolean     DEFAULT FALSE,
_IntervalAGAIN     interval    DEFAULT '100 ms'::interval,
_IntervalDONE      interval    DEFAULT NULL,
_RunAfterTimestamp timestamptz DEFAULT NULL,
_RunUntilTimestamp timestamptz DEFAULT NULL,
_RunAfterTime      time        DEFAULT NULL,
_RunUntilTime      time        DEFAULT NULL,
_ConnectionPool    text        DEFAULT NULL,
_LogTableAccess    boolean     DEFAULT TRUE,
_RequestedBy       text        DEFAULT session_user,
_RequestedAt       timestamptz DEFAULT now()
)
RETURNS integer
LANGUAGE plpgsql
SET search_path TO public, pg_temp
AS $FUNC$
DECLARE
_OK boolean;
_JobID integer;
_IdenticalConfiguration boolean;
_ConnectionPoolID integer;
_CycleFirstProcessID integer;
BEGIN
IF cron.Is_Valid_Function(_Function) IS NOT TRUE THEN
    RAISE EXCEPTION 'Function % is not a valid CronJob function.', _Function
    USING HINT = 'It must return BATCHJOBSTATE and the pgcronjob user must have been explicitly granted EXECUTE on the function.';
END IF;

IF _ConnectionPool IS NOT NULL THEN
    SELECT ConnectionPoolID, CycleFirstProcessID INTO STRICT _ConnectionPoolID, _CycleFirstProcessID FROM cron.ConnectionPools WHERE Name = _ConnectionPool;
END IF;

INSERT INTO cron.Jobs ( Function,       Processes, Concurrent, Enabled, RunIfWaiting, RetryOnError, RandomInterval, IntervalAGAIN, IntervalDONE, RunAfterTimestamp, RunUntilTimestamp, RunAfterTime, RunUntilTime, ConnectionPoolID, LogTableAccess, RequestedBy, RequestedAt)
VALUES                (_Function::text,_Processes,_Concurrent,_Enabled,_RunIfWaiting,_RetryOnError,_RandomInterval,_IntervalAGAIN,_IntervalDONE,_RunAfterTimestamp,_RunUntilTimestamp,_RunAfterTime,_RunUntilTime,_ConnectionPoolID,_LogTableAccess,_RequestedBy,_RequestedAt)
RETURNING JobID INTO STRICT _JobID;

INSERT INTO cron.Processes (JobID) SELECT _JobID FROM generate_series(1,_Processes);

IF _ConnectionPool IS NOT NULL AND _CycleFirstProcessID IS NULL THEN
    UPDATE cron.ConnectionPools SET
        CycleFirstProcessID = (SELECT MIN(ProcessID) FROM cron.Processes WHERE JobID = _JobID)
    WHERE ConnectionPoolID = _ConnectionPoolID
    AND CycleFirstProcessID IS NULL
    RETURNING TRUE INTO STRICT _OK;
END IF;

RETURN _JobID;
END;
$FUNC$;

ALTER FUNCTION cron.Register(
_Function          regprocedure,
_Processes         integer,
_Concurrent        boolean,
_Enabled           boolean,
_RunIfWaiting      boolean,
_RetryOnError      interval,
_RandomInterval    boolean,
_IntervalAGAIN     interval,
_IntervalDONE      interval,
_RunAfterTimestamp timestamptz,
_RunUntilTimestamp timestamptz,
_RunAfterTime      time,
_RunUntilTime      time,
_ConnectionPool    text,
_LogTableAccess    boolean,
_RequestedBy       text,
_RequestedAt       timestamptz
) OWNER TO pgcronjob;
