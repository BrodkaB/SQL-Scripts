--1) Create table in DBA database dbo.AuditCheckLog

CREATE TABLE DBA.dbo.AuditCheckLog (
	CheckTime DATETIME);

--2) Setup DatabaseMail service
--3) Setup Instance level Audit

CREATE SERVER AUDIT [NameOfAudit]
TO FILE (FILEPATH = 'path for your files\', MAXSIZE =10MB, MAX_ROLLOVER_FILES = 100);
ALTER SERVER AUDIT [NameOfAudit] WITH (STATE=ON);

--4) Setup Audit specification with same variables which will point to created audit

CREATE SERVER AUDIT SPECIFICATION [NameOfAuditSpecification]
FOR SERVER AUDIT [NameOfAudit]
ADD (SUCCESSFUL_LOGIN_GROUP),
ADD (FAILED_LOGIN_GROUP);
ALTER SERVER AUDIT SPECIFICATION [NameOfAuditSpecification] WITH (STATE=ON);

--5) Execute below script with changing required variables
---Declaring variables and temporary table

DECLARE @EmailRecipient NVARCHAR(255) = N'brodkab@ryanair.com';		--Enter your recipients
DECLARE @EmailSubject NVARCHAR(255) = N'SQL Instance login audit';	--Enter name of mail subject
DECLARE @EmailBody NVARCHAR(MAX);
DECLARE @LastCheckTime DATETIME;
SELECT @LastCheckTime = MAX(CheckTime) FROM DBA.dbo.AuditCheckLog;
DECLARE @ProfileName NVARCHAR(255)
SELECT @ProfileName = p.name FROM msdb.dbo.sysmail_principalprofile AS pp JOIN msdb.dbo.sysmail_profile AS p ON pp.profile_id = p.profile_id
WHERE pp.is_default = 1;

DECLARE @temp AS TABLE
(
    LoginName NVARCHAR(300),
    LoginDate NVARCHAR(300)
);

---Inserting data from audit logs into temp table. 

INSERT INTO @temp

---This step is taking out all logins to the instance from the last execution of this job and putting current execution date into dba.dbo.AuditCheckLog tabel

	---SELECT server_principal_name, event_time
	---FROM sys.fn_get_audit_file ('F:\Mail_logins_tst\*.sqlaudit', DEFAULT, DEFAULT)
	---WHERE event_time >@LastCheckTime

		---This step is taking every uniqe login that accesses SQL Server instance from last job execution. It's preventing from loading thousands of rows into table

		SELECT DISTINCT server_principal_name, MIN(event_time) AS LoginDate
		FROM sys.fn_get_audit_file ('F:\Mail_logins_tst\*.sqlaudit', DEFAULT, DEFAULT)
		WHERE event_time >@LastCheckTime
		GROUP BY server_principal_name

INSERT INTO dba.dbo.AuditCheckLog (CheckTime) VALUES (GETDATE());

---Setting up HTML email body to be sent

SELECT @EmailBody
		= N'<html>' 
			+ N'<head>' 
				+ N'<style>' 
					+ N'table {border-collapse: collapse;}'
					+ N'th, td {border: 1px solid black; padding: 5px;}' 
				+ N'</style>' 
			+ N'</head>' 
			+ N'<body>'
				+ N'<h2>SQL instance login audit</h2>' 
				+ N'<table>' 
					+ N'<tr>' 
						+ N'<th>LoginName</th>'
						+ N'<th>LoginDate</th>' 
					+ N'</tr>';

SELECT @EmailBody
		= @EmailBody 
				+ N'<tr>' 
					+ N'<td>' + LoginName + N'</td>' 
					+ N'<td>' + LoginDate + N'</td>' 
FROM @temp

SET @EmailBody = @EmailBody + N'</table>' + N'</body>' + N'</html>';

SELECT @EmailBody;

---Executing stored procedure for email sending

EXEC msdb.dbo.sp_send_dbmail
    @profile_name = @ProfileName,		--'YourMailProfile', Replace with the name of your Database Mail profile
    @recipients = @EmailRecipient,
    @subject = @EmailSubject,
    @body = @EmailBody,
    @body_format = 'HTML';
New File at / · BrodkaB/SQL-Scripts
