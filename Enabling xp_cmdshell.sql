---Enabling sp_configure advanced options
EXEC sp_configure 'show advanced options', '1'
RECONFIGURE

      ---Enabling xp_cmdshell command
      EXEC sp_configure 'xp_cmdshell', '1'
      RECONFIGURE
      
            ---Using xp_cmdshell to see current SQL user that you are logged as
            xp_cmdshell 'whoami'
