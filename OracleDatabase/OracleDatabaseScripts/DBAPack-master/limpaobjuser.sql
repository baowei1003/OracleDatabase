/*
PARA MATAR TABELAS ORFAS DO ADVANCED QUEUE.
alter session set events '10851 trace name context forever, level 2';
drop table xxxx;
*/

UNDEFINE P_OWNER
DEFINE VX_INSTANCE='&1.'
DEFINE VX_OWNER='&2.'
SET DEFINE ON SERVEROUT ON VERIFY OFF
PROMPT
ACCEPT P_CONTINUE CHAR FORMAT A1 DEFAULT 'N' PROMPT "Deseja remover os objetos de &VX_OWNER.@&VX_INSTANCE. (s/N)? "
PROMPT
DECLARE

  CURSOR C1 IS
    SELECT
      OBJECT_TYPE, OWNER, '"'||OBJECT_NAME||'"' OBJECT_NAME,
      'DROP ' || OBJECT_TYPE || ' ' || OWNER || '.' || '"'||OBJECT_NAME||'"'  ||
      DECODE( OBJECT_TYPE, 'TABLE', ' CASCADE CONSTRAINTS PURGE' ) DROP_STMT
    FROM DBA_OBJECTS
    CROSS JOIN V$INSTANCE
    WHERE OBJECT_TYPE IN
         (
           'TABLE',
           'DIMENSION',
           'MATERIALIZED VIEW',
           'VIEW',
           'SEQUENCE',
           'SYNONYM',
           'PROCEDURE',
           'FUNCTION',
           'PACKAGE',
           'TYPE',
           'QUEUE',
           'JAVA SOURCE',
           'JAVA RESOURCE',
           'JAVA CLASS'
         )
    AND OWNER IN UPPER( '&VX_OWNER.' )
    AND LOWER(INSTANCE_NAME) LIKE LOWER('&VX_INSTANCE.')
    AND OBJECT_NAME NOT LIKE 'BIN$%'
    AND OBJECT_NAME NOT LIKE 'DR$%'
    ORDER BY DECODE (OBJECT_TYPE, 'INDEX', 1, 'MATERIALIZED VIEW', 2, 'QUEUE', 2, 'TYPE', 4, 3 );

    v_existe NUMBER(1);

BEGIN

  IF UPPER( '&P_CONTINUE.' ) != 'S' THEN
     dbms_output.put_line( '#### ABORTADO: Script cancelado por solicitacao do usuario. ####'  );
     RETURN;
  END IF;

  SELECT COUNT(*)
  INTO v_existe
  FROM DBA_USERS
  CROSS JOIN V$INSTANCE
  WHERE USERNAME = UPPER('&VX_OWNER.')
  AND UPPER(INSTANCE_NAME) LIKE UPPER('&VX_INSTANCE.');

  IF v_existe = 0 THEN
     dbms_output.put_line( '#### ABORTADO: Instancia "'||LOWER('&VX_INSTANCE.')||'" incorreta ou o esquema "'||UPPER('&VX_OWNER.')||'" nao existe. ####' );
     RETURN;
  END IF;
  
  --EXECUTE IMMEDIATE 'PURGE DBA_RECYCLEBIN';

  FOR R1 IN C1 LOOP
    BEGIN
      IF R1.OBJECT_TYPE='QUEUE' THEN
        DBMS_AQADM.DROP_QUEUE(R1.OWNER||'.'||R1.OBJECT_NAME);
      ELSE
        BEGIN
          EXECUTE IMMEDIATE R1.DROP_STMT;
        EXCEPTION
          WHEN OTHERS THEN
           IF SQLCODE=-24005 THEN
             DBMS_AQADM.DROP_QUEUE_TABLE( R1.OWNER||'.'||R1.OBJECT_NAME, TRUE);
           END IF;
        END;           
      END IF;  
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(R1.DROP_STMT||CHR(10)||SQLERRM);
    END;
  END LOOP;
  
  --EXECUTE IMMEDIATE 'PURGE DBA_RECYCLEBIN';
  
END;
/

PROMPT
PROMPT OBJETOS DE &VX_OWNER.@&VX_INSTANCE.
SELECT OBJECT_TYPE, COUNT(*) QTDE 
FROM DBA_OBJECTS 
CROSS JOIN V$INSTANCE
WHERE OWNER=UPPER( '&VX_OWNER.' )
AND UPPER(INSTANCE_NAME) LIKE UPPER('&VX_INSTANCE.')
GROUP BY OBJECT_TYPE
/

UNDEFINE VX_OWNER VX_INSTANCE P_CONTINUE