-- хранилище данных

-- создаем схемы
create schema dwh;
create schema rejected;


--Dim_Calendar - справочник дат
create table dwh.Dim_Calendar
as
with dates as (
    select dd::date as dt
    from generate_series
            ('2010-01-01'::timestamp
            , '2030-01-01'::timestamp
            , '1 day'::interval) dd )
select
    to_char(dt, 'YYYYMMDD')::int as id, -- суррогатный ключ
    dt as date, --дата
    to_char(dt, 'YYYY-MM-DD') as ansi_date, --дата в формате ansi 
    date_part('isodow', dt)::int as day, -- номер дня в году
    date_part('week', dt)::int as week_number, -- номер недели в году
    date_part('month', dt)::int as month, -- номер месяца в году
    date_part('isoyear', dt)::int as year, -- год
    (date_part('isodow', dt)::smallint between 1 and 5)::int as week_day, -- рабочий день
    (to_char(dt, 'YYYYMMDD')::int in (
        20130101, 20130102, 20130103, 20130104, 20130105, 20130106, 20130107,
        20130108, 20130223, 20130308, 20130310, 20130501, 20130502, 20130503,
        20130509, 20130510, 20130612, 20131104, 20140101, 20140102, 20140103,
        20140104, 20140105, 20140106, 20140107, 20140108, 20140223, 20140308,
		20140310, 20140501, 20140502, 20140509, 20140612, 20140613, 20141103,
        20141104, 20150101, 20150102, 20150103, 20150104, 20150105, 20150106,
        20150107, 20150108, 20150109, 20150223, 20150308, 20150309, 20150501,
        20150504, 20150509, 20150511, 20150612, 20151104, 20160101, 20160102,
        20160103, 20160104, 20160105, 20160106, 20160107, 20160108, 20160222,
        20160223, 20160307, 20160308, 20160501, 20160502, 20160503, 20160509,
        20160612, 20160613, 20161104, 20170101, 20170102, 20170103, 20170104,
        20170105, 20170106, 20170107, 20170108, 20170223, 20170224, 20170308,
        20170501, 20170508, 20170509, 20170612, 20171104, 20171106, 20180101,
        20180102, 20180103, 20180104, 20180105, 20180106, 20180107, 20180108,
        20180223, 20180308, 20180309, 20180430, 20180501, 20180502, 20180509,
        20180611, 20180612, 20181104, 20181105, 20181231, 20190101, 20190102,
        20190103, 20190104, 20190105, 20190106, 20190107, 20190108, 20190223,
        20190308, 20190501, 20190502, 20190503, 20190509, 20190510, 20190612,
        20191104, 20200101, 20200102, 20200103, 20200106, 20200107, 20200108,
        20200224, 20200309, 20200501, 20200504, 20200505, 20200511, 20200612, 
        20201104, 20210101, 20210102, 20210103, 20210104, 20210105, 20210106,
        20210107, 20210108, 20210109, 20210110, 20210222, 20210223, 20210308,
        20210503, 20210510, 20210614, 20211104, 20211105, 20211231, 20220101,
        20220102, 20220103, 20220104, 20220105, 20220106, 20220107, 20220108,
        20220109, 20220223, 20220307, 20220308, 20220502, 20220503, 20220509,
        20220510, 20220613, 20221104, 20221231
        ))::int as holiday -- официальный выходной
from dates
order by dt;

alter table dwh.Dim_Calendar add primary key (id);

-- Dim_Passengers - справочник пассажиров
create table dwh.Dim_Passengers (
	id serial8 not null primary key, -- суррогатный ключ
	passenger_id varchar(20), -- номер документа,удостоверяющего личность
	passenger_name text, -- фамилия и имя пассажира
	phone varchar(12), -- контактный номер телефона
	email varchar(255) -- контактный e-mail 
);


-- Dim_Aircrafts - справочник самолетов
create table dwh.Dim_Aircrafts (
	id serial8 not null primary key, -- суррогатный ключ
	aircraft_code bpchar(3), -- Код самолета, IATA
	model text, -- Модель самолета
	range int4, -- Максимальная дальность полета, км
	seats_count int -- кол-во мест
);


-- Dim_Airports - справочник аэропортов
create table dwh.Dim_Airports (
	id serial8 not null primary key, -- суррогатный ключ
	airport_code bpchar(3), -- Код аэропорта
	airport_name text, -- Название аэропорта
	city text, -- Город
	longitude float8, -- Координаты аэропорта: долгота
	latitude float8, -- Координаты аэропорта: широта
	timezone text -- Временная зона аэропорта
);


-- Dim_Tariff - справочник тарифов (Эконом/бизнес и тд)
create table dwh.Dim_Tariff (
	id serial8 not null primary key, -- суррогатный ключ
	fare_conditions varchar(10) -- Класс обслуживания
);

-- Fact_Flights - совершенные перелеты
create table dwh.Fact_Flights (
	date_key int not null references dwh.Dim_Calendar(id), -- Дата вылета (key)
	passenger_key int8 not null references dwh.Dim_Passengers, -- Пассажир (key)
	aircraft_key int8 not null references dwh.Dim_Aircrafts, -- Самолет (key)
	departure_airport_key int8 not null references dwh.Dim_Airports, -- Аэропорт вылета (key)
	arrival_airport_key int8 not null references dwh.Dim_Airports, -- Аэропорт прилета (key)
	tariff_key int8 not null references dwh.Dim_Tariff, -- Класс обслуживания (key)
	actual_departure timestamptz, -- Дата и время вылета (факт)
	actual_arrival timestamptz, -- Дата и время прилета (факт)
   	delay_departure int, -- Задержка вылета (разница между фактической и запланированной датой в секундах)
   	delay_arrival int, -- Задержка прилета (разница между фактической и запланированной датой в секундах)
   	amount numeric(10,2) -- Стоимость
);
	

-- rejected-таблицы
create table rejected.airports (
	airport_code bpchar(3), 
	airport_name text,
	city text,
	longitude float8, 
	latitude float8, 
	timezone text 
); 

create table rejected.aircrafts (
	aircraft_code bpchar(3),
	model text,
	range int4, 
	seats_count int
);

create table rejected.passengers (
	passenger_id varchar(20),
	passenger_name text, 
	phone varchar(255), 
	email varchar(255)  
);

create table rejected.flights (
	actual_departure timestamptz,
	actual_arrival timestamptz, 
   	delay_departure int, 
   	delay_arrival int, 
   	amount numeric(10,2),
   	scheduled_departure timestamptz,
   	scheduled_arrival timestamptz
);
