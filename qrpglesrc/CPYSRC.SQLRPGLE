       dcl-pi CPYSRC;
          library char(10);
          srcfile char(10);
          member  char(10);
       end-pi;
       dcl-s source_type char(10);

        exec sql
        SELECT SOURCE_TYPE into :source_type
        FROM QSYS2.SYSPARTITIONSTAT
        WHERE SYSTEM_TABLE_SCHEMA = :library
          AND SYSTEM_TABLE_NAME = :srcfile
          AND SYSTEM_TABLE_MEMBER = :member;

        exec sql
        DELETE FROM LONGDM/SRCEXT;

        exec sql
        INSERT INTO LONGDM/SRCEXT VALUES(:source_type);

       *inlr = *on;
       return;