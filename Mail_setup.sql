DECLARE @cmd VARCHAR(8000);
DECLARE @file_path NVARCHAR(255);
SET @cmd = 'bcp "SELECT * FROM dba.dbo.ConsolidatedAuditLogs" queryout "C:\Temp\SQLAudit.csv" -c -t, -T -S ' + @@SERVERNAME;
SET @file_path = N'C:\Temp\SQLAudit.csv';
EXEC xp_cmdshell @cmd;

---This step is creating mail body and sending mail to provided recipients

DECLARE @EmailRecipient NVARCHAR(255) = N'maloneyr@ryanair.com;costellod@ryanair.com;wintel-businessservices-team@ryanair.com';		--Enter your recipients
DECLARE @EmailSubject NVARCHAR(255) = N'SQL Instance login audit';	--Enter name of mail subject
DECLARE @EmailBody NVARCHAR(MAX);
DECLARE @ProfileName NVARCHAR(255) = N'CHOVEEAMSQL2022_Audit'
SELECT @ProfileName = p.name FROM msdb.dbo.sysmail_principalprofile AS pp JOIN msdb.dbo.sysmail_profile AS p ON pp.profile_id = p.profile_id
WHERE pp.is_default = 1;

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
						+ N'<th>Servername</th>'
						+ N'<th>LoginName</th>'
						+ N'<th>LoginDate</th>' 
						+ N'<th>Succes1Failed0</th>'
						+ N'<th>ClientNameOrIP</th>'
					+ N'</tr>';

SELECT @EmailBody
		= @EmailBody 
				+ N'<tr>' 
					+ N'<td>' + ISNULL(ServerName, '') + N'</td>'
					+ N'<td>' + ISNULL(LoginName, '') + N'</td>' 
					+ N'<td>' + ISNULL(LoginDate, '') + N'</td>' 
					+ N'<td>' + ISNULL(Succes1Failed0, '') + N'</td>'
					+ N'<td>' + ISNULL(ClientNameOrIP, '') + N'</td>'
FROM DBA.dbo.ConsolidatedAuditLogs

SET @EmailBody = @EmailBody + N'</table>' + N'</body>' + N'</html>';

SELECT @EmailBody;

---Executing stored procedure for email sending

EXEC msdb.dbo.sp_send_dbmail
    @profile_name = @ProfileName,		--'YourMailProfile', Replace with the name of your Database Mail profile
    @recipients = @EmailRecipient,
    @subject = @EmailSubject,
    @body = @EmailBody,
    @body_format = 'HTML',
	@file_attachments = @file_path;
