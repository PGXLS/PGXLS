revoke usage on schema pgxls from public;
revoke execute on all functions in schema pgxls from public;
revoke execute on all procedures in schema pgxls from public;

create or replace function pgxls._temp_zip_create() returns int language plpgsql as $$
begin
  if to_regtype('pgxls_temp_zip_file') is null then	
    create temp sequence if not exists pgxls_id_seq cycle;
    create temp table if not exists pgxls_temp_zip_file(xls_id int, name varchar(32), part int, subpart bigserial, body bytea not null);
  end if; 
  return nextval('pgxls_id_seq'); 
end
$$;

create or replace procedure pgxls._temp_zip_delete(xls_id int) language plpgsql as $$
begin
  delete from pgxls_temp_zip_file zf where zf.xls_id=_temp_zip_delete.xls_id;  
end
$$;

create or replace procedure pgxls._temp_zip_file_append(xls_id int, name varchar, part int, body bytea) language plpgsql as $$
begin
  insert into pgxls_temp_zip_file(xls_id, name, part, body) values (xls_id, name, part, body);
end;
$$;

create or replace procedure pgxls._temp_zip_file_append(xls_id int, name varchar, part int, body text) language plpgsql as $$
begin
  call pgxls._temp_zip_file_append(xls_id, name, part, pgxls._build_zip_utf8(body));
end;
$$;

create or replace function pgxls._temp_zip_load(xls_id int) returns setof bytea language plpgsql as $$
begin
  return query execute 'select body from pgxls_temp_zip_file where xls_id='||xls_id||' order by name collate "C", part, subpart';  
end;
$$; 

create or replace function pgxls._temp_zip_files(xls_id int) returns varchar[] language plpgsql as $$
begin
  return (
    select coalesce(array_agg(distinct name collate "C" order by name collate "C"),array[]::varchar[])
      from pgxls_temp_zip_file zf
      where zf.xls_id=_temp_zip_files.xls_id
  );
end;  
$$; 

create or replace procedure pgxls._temp_zip_file_info(xls_id int, name varchar, inout len bigint, inout crc bigint) language plpgsql as $$
declare
  v_file_subpart record;
begin
  len := 0;
  crc := 4294967295;
  for v_file_subpart in (select body from pgxls_temp_zip_file f where f.xls_id=_temp_zip_file_info.xls_id and f.name=_temp_zip_file_info.name order by part, subpart) loop
    len := len+length(v_file_subpart.body);
    for i in 0..length(v_file_subpart.body)-1 loop
        crc = (crc # get_byte(v_file_subpart.body, i))::bigint;
        for j in 1..8 loop
            crc := ((crc >> 1) # (3988292384 * (crc & 1)))::bigint;
        end loop;
    end loop;       
  end loop;
  crc := crc # 4294967295;
end;  
$$;