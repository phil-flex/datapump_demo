------------------------------------------------------------------------------------
-- File name: exp_schema.prc
-- Purpose:   To demonstrate a schema import with some additional datapump elements.
-- Author:    Christoph Ruepprich
--            http://ruepprich.wordpress.com
--            cruepprich@gmail.com
-- Notes:     For educational purposes only.
--
------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE exp_schema IS
  l_dp_handle PLS_INTEGER; --datapump job handle
  l_job_name  VARCHAR2(30); --name for datapump job
  l_dumpfile  VARCHAR2(30); --name of dump file
  l_logfile   VARCHAR2(30); --name of log file
  l_dpdir     VARCHAR2(30); --name of datapump directory object
  l_errors    PLS_INTEGER := 0; --number of errors logged during monitoring

  e_start_job1 EXCEPTION;
  e_start_job2 EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_start_job1, -31626); --failed datapump events can leave master table behind
  PRAGMA EXCEPTION_INIT(e_start_job2, -31634); --failed datapump events can leave session behind  
BEGIN
  l_job_name := 'dp_schema';
  l_dumpfile := l_job_name || '.dmp';
  l_logfile  := l_job_name || '.log';
  l_dpdir    := 'DATA_PUMP_DIR';

  IF file_exists_fn(p_filename => l_dumpfile, p_directory => l_dpdir)
  THEN
    raise_application_error(-20002,
                            'Dumpfile ' || l_dumpfile || ' already exists.');
  END IF;

  BEGIN --open job
    l_dp_handle := dbms_datapump.open(operation => 'EXPORT',
                                      job_mode  => 'SCHEMA',
                                      job_name  => 'dp_schema',
                                      version   => '10.0.0');
  EXCEPTION
    WHEN e_start_job1 THEN
    
      DECLARE
        l_table_name VARCHAR2(30);
      BEGIN
        SELECT nvl(MAX(table_name), 'x')
          INTO l_table_name
          FROM user_tables
         WHERE table_name = l_job_name;
        IF l_table_name != 'x'
        THEN
          dbms_output.put_line('Datapump Master Table ' || l_job_name ||
                               ' exists.');
        END IF;
      END;
    
      RAISE;
    
    WHEN e_start_job2 THEN
      dbms_output.put_line('Check for existing data pump session.');
      RAISE;
    WHEN OTHERS THEN
      raise_application_error(-20000,
                              'Error when opening job: ' || SQLERRM);
  END;

  BEGIN -- create view
    dbms_datapump.create_job_view(job_schema => USER,
                                  job_name   => 'dp_schema',
                                  view_name  => 'DP_SCHEMA_VW');
  EXCEPTION
    WHEN OTHERS THEN
      dbms_datapump.detach(handle => l_dp_handle);
      raise_application_error(-20008,
                              'Error when adding view: ' || SQLERRM);
  END;

  BEGIN --add dump file
    dbms_datapump.add_file(handle    => l_dp_handle,
                           filename  => l_dumpfile,
                           directory => l_dpdir,
                           filesize  => '1G');
  EXCEPTION
    WHEN OTHERS THEN
      dbms_datapump.detach(handle => l_dp_handle);
      raise_application_error(-20010,
                              'Error when adding dump file: ' || SQLERRM);
  END;

  BEGIN --add log file
    dbms_datapump.add_file(handle    => l_dp_handle,
                           filename  => l_logfile,
                           directory => l_dpdir,
                           filetype  => dbms_datapump.ku$_file_type_log_file);
  
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20020,
                              'Error when adding log file: ' || SQLERRM);
  END;

  BEGIN --specify schema
    dbms_datapump.metadata_filter(handle => l_dp_handle,
                                  NAME   => 'SCHEMA_EXPR',
                                  VALUE  => '=''SCOTT''');
  
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20030,
                              'Error when adding metadata filter: ' ||
                              SQLERRM);
  END;

  BEGIN --data filter on dept
    dbms_datapump.data_filter(handle     => l_dp_handle,
                              NAME       => 'SUBQUERY',
                              VALUE      => 'where deptno = 20',
                              table_name => 'DEPT');
  
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20032,
                              'Error when setting data filter 1: ' ||
                              SQLERRM);
  END;

  BEGIN --data filter on emp
    dbms_datapump.data_filter(handle     => l_dp_handle,
                              NAME       => 'SUBQUERY',
                              VALUE      => 'where job = ''ANALYST'' AND deptno = 20',
                              table_name => 'EMP');
  
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20032,
                              'Error when setting data filter 2: ' ||
                              SQLERRM);
  END;

  /*  BEGIN --start job
      dbms_datapump.start_job(handle => l_dp_handle);
    
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20040,
                                'Error when starting job: ' || SQLERRM);
    END;
  
    BEGIN --monitor job
       monitor_dp(p_dp_handle => l_dp_handle, p_errors => l_errors);
    EXCEPTION
       WHEN OTHERS THEN
          dbms_output.put_line('Error monitoring the dp job <' ||SQLERRM || '> ');
          RAISE;       
    END;
  */
  BEGIN
    --detach job
    dbms_datapump.detach(handle => l_dp_handle);
  
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20050, SQLERRM);
  END;

EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line('Main exception: ' || SQLERRM);
    RAISE;
END exp_schema;
/
