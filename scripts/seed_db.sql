-- seed_db.sql — грязные данные для таблицы nickname (service_raw / db_raw)
-- Категории: нормализуемые (регистр, пробелы по краям) и отклоняемые
-- (слишком длинные, пробел внутри, запрещённые символы, кириллица).
--
-- Случайность строится в списке SELECT: md5(clock_timestamp() || g) уникален
-- на каждой строке (g — номер строки). Подзапросы с generate_series не используются:
-- планировщик PostgreSQL может вычислить некоррелированный подзапрос один раз
-- на все строки (даже с LATERAL), а volatile-функции в target list выполняются
-- гарантированно на каждую строку.

-- Категория 1: валидные после нормализации (случайный регистр + пробелы по краям)
INSERT INTO nickname (nick)
SELECT repeat(' ', 1 + floor(random() * 3)::int)
       || CASE WHEN random() < 0.5
               THEN upper(left(md5(clock_timestamp()::text || g.g::text), 4 + floor(random() * 12)::int))
               ELSE lower(left(md5(clock_timestamp()::text || g.g::text), 4 + floor(random() * 12)::int))
          END
       || repeat(' ', 1 + floor(random() * 3)::int)
FROM generate_series(1, 400) AS g;

-- Категория 2: слишком длинные (17-25 символов) → отклонить по правилу "не более 16"
INSERT INTO nickname (nick)
SELECT left(md5(clock_timestamp()::text || g.g::text), 17 + floor(random() * 9)::int)
FROM generate_series(1, 150) AS g;

-- Категория 3: пробел внутри → отклонить
INSERT INTO nickname (nick)
SELECT left(md5(clock_timestamp()::text || g.g::text), 3 + floor(random() * 5)::int)
       || ' '
       || left(md5(clock_timestamp()::text || (g.g + 1000000)::text), 3 + floor(random() * 5)::int)
FROM generate_series(1, 150) AS g;

-- Категория 4: запрещённые символы (#, -, @) → отклонить
INSERT INTO nickname (nick)
SELECT left(s.s, 2) || (ARRAY['#', '-', '@'])[1 + floor(random() * 3)::int] || right(s.s, -2)
FROM (
    SELECT left(md5(clock_timestamp()::text || g.g::text), 4 + floor(random() * 10)::int) AS s
    FROM generate_series(1, 150) AS g
) AS s;

-- Категория 5: кириллица → отклонить (hex-символы md5 переводим в кириллицу через translate)
INSERT INTO nickname (nick)
SELECT translate(left(md5(clock_timestamp()::text || g.g::text), 4 + floor(random() * 10)::int),
                 '0123456789abcdef', 'абвгдезиклмнопрст')
FROM generate_series(1, 150) AS g;
