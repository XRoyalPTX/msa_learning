# План обучения: два микросервиса на gRPC + Docker

Целевой проект (задание от друга):
- 2 микросервиса на Python и Go, у каждого своя БД (PostgreSQL)
- 1 таблица в каждой БД, заполненная рандомными данными (SQL-скриптом)
- Сервисы общаются по gRPC: сервис 1 отдаёт "сырые" данные, сервис 2 нормализует и пишет в свою БД
- БД подняты в Docker локально, оркестрация через Docker Compose
- Без фронта, без Kafka

Стек: Python, PostgreSQL, SQLAlchemy, Alembic (знакомый стек) + gRPC, Docker, Docker Compose (доизучение)

---

## Roadmap (прогресс)

- [x] Структура репозитория: монорепо, изолированные папки сервисов
- [x] Docker Compose: `db_raw` (postgres:16-alpine, volume, healthcheck, порт 5432)
- [x] `service_raw/requirements.txt` (SQLAlchemy, Alembic, psycopg2-binary, grpcio, grpcio-tools)
- [x] `service_raw/app/models.py` — модель `Nickname`
- [x] `service_raw/app/db.py` — engine + Session, конфиг из `.env`
- [x] `service_raw/.env` (DB_HOST/PORT/NAME/USER/PASSWORD)
- [x] Alembic в `service_raw`: init, связка `env.py` с моделью, миграция создана и применена (`alembic upgrade head`)
- [x] `scripts/seed_db.sql` — 1000 грязных строк в 5 категориях, залито в `db_raw`
- [x] Docker Compose: `db_normalized` 
- [x] `proto/nicknames/nickname.proto` — контракт gRPC
- [x] Кодогенерация из `.proto` (Python-стабы + Go-стабы)
- [x] `service_raw/app/main.py` — gRPC-сервер, ручки `GetNickname` / `ListNicknames`, проверен Python-клиентом
- [ ] `service_normalized` (**на Go**): layout, go.mod, models, .env, миграции (golang-migrate)
- [ ] `service_normalized`: normalizer (правила нормализации/валидации), gRPC-клиент, main.go
- [ ] Проверка end-to-end: грязные данные → gRPC (Python-сервер → Go-клиент) → чистые в `db_normalized`
- [ ] Dockerfile'ы для сервисов + запуск сервисов через compose
- [ ] Полировка: автозапуск миграций при старте, retry-ожидание БД, логи

---

## Структура репозитория (актуальная)

```
msa_learning/
├── docker-compose.yml              # общий: db_raw + db_normalized (+ позже сами сервисы)
├── .env                            # env для compose
├── proto/
│   └── nicknames/
│       └── nickname.proto          # контракт gRPC, общий для обоих сервисов
├── scripts/
│   └── seed_db.sql                 # SQL-скрипт: грязные данные для db_raw
├── service_raw/                    # сервис 1 (Python): хранит сырые данные, gRPC-СЕРВЕР
│   ├── app/
│   │   ├── main.py                 # gRPC-сервер (NicknameService + serve())
│   │   ├── models.py               # SQLAlchemy-модель Nickname
│   │   ├── db.py                   # engine + Session, конфиг из .env
│   │   └── test_client.py          # (временный, для ручной проверки)
│   ├── nicknames/                  # СГЕНЕРИРОВАНО из proto, не редактировать
│   │   ├── nickname_pb2.py         # сообщения
│   │   └── nickname_pb2_grpc.py    # сервисер + клиентский stub
│   ├── alembic/                    # миграции сервиса 1
│   │   └── versions/
│   ├── alembic.ini
│   ├── .env                        # DB_HOST/PORT/NAME/USER/PASSWORD
│   ├── requirements.txt
│   └── Dockerfile                  # (на финальном этапе)
├── service_normalized/             # сервис 2 (Go): gRPC-КЛИЕНТ + нормализация
│   ├── internal/
│   │   └── nicknamepb/             # СГЕНЕРИРОВАНО из proto, не редактировать
│   │       ├── nickname.pb.go      # сообщения
│   │       └── nickname_grpc.pb.go # клиентский stub
│   ├── .env
│   ├── go.mod                      # зависимости + tool-инструменты (protoc-плагины)
│   ├── go.sum
│   └── Dockerfile
└── README.md
```

Ключевые идеи:
- `proto/` на уровне корня, потому что **контракт общий**: обе стороны генерируют код из одного `.proto`-файла.
- Папки со сгенерированным кодом (`nicknames/`, `internal/nicknamepb/`) не редактируют руками — только перегенерируют.
- У сервисов разные стеки и независимые зависимости (`requirements.txt` vs `go.mod`).
- Никакого импорта кода сервиса 1 из сервиса 2 — связь только по gRPC.

## Этап 1. Docker (~2-3 часа)

Что изучить:
- Образ vs контейнер, `docker pull`, `docker run`, `docker ps`, `docker logs`, `docker exec`
- Порты: `-p 5432:5432` (маппинг хост → контейнер)
- Volumes: где живут данные контейнера, почему без volume данные пропадут при удалении контейнера
- Переменные окружения: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- Подключиться извне к контейнеру

Практика: подними **один** контейнер postgres вручную, подключись к нему через `psql` или IDE (DBeaver/DataGrip), создай таблицу руками. Потом удали контейнер с volume и без — почувствуй разницу.

## Этап 2. Docker Compose (~2-3 часа)

Что изучить:
- `docker-compose.yml`: `services`, `image`, `ports`, `environment`, `volumes`
- Команды: `docker compose up -d`, `down`, `logs -f`, `ps`
- Сеть compose: контейнеры видят друг друга по имени сервиса (это пригодится, если сервисы тоже уедут в Docker)

Практика: напиши `docker-compose.yml` с **двумя** postgres:
- `db_raw` → порт `5432`
- `db_normalized` → порт `5433`
- у каждого свой named volume (`pg_raw_data`, `pg_normalized_data`)

Оба должны быть доступны с хоста одновременно. Это и есть "1 БД на 1 микросервис".

## Этап 3. gRPC (~4-6 часов, самое важное новое)

Что изучить:
- Чем gRPC отличается от REST: protobuf-бинарный формат, строгий контракт, кодогенерация
- `.proto`-синтаксис: `message`, `service`, `rpc`, типы данных, `repeated`
- Кодогенерация: `python -m grpc_tools.protoc -I proto --python_out=... --grpc_python_out=...`
- `grpcio` + `grpcio-tools`, синхронный сервер и клиент (для учебного проекта синхронного хватит)
- Unary / server-streaming rpc (начни с unary)

Практика: **до** сервисов сделай мини-демо — один файл `server.py` и `client.py`, один метод `GetUser(id) → User`. Заставь клиента вызвать сервер. Потом усложни: метод `ListUsers() → repeated User`.

## Этап 4. Сервис 1: raw-данные (~3-4 часа)

Стек, который ты знаешь, но теперь в контексте микросервиса:
- Alembic-миграция → таблица с "сырыми" данными (например, `raw_users` с кривыми строками: имена в разном регистре, лишние пробелы, телефоны в разных форматах)
- SQL-скрипт `fill_db.sql` с рандомными значениями (генерируй через `generate_series` + `random()` прямо в SQL — это часть задания)
- SQLAlchemy-модель
- gRPC-сервер с ручками: `GetRawUser(id)`, `ListRawUsers()`

## Этап 5. Сервис 2: нормализация (~3-4 часа)

- Своя Alembic-миграция → таблица `normalized_users` (чистые поля: lowercase-имя, единый формат телефона, дата создания)
- gRPC-клиент, который дергает сервис 1
- Логика нормализации в отдельном модуле
- Запись нормализованных данных в свою БД

Проверка end-to-end: в `db_raw` лежат грязные данные → сервис 2 забирает их по gRPC → в `db_normalized` появляются чистые.

## Этап 6. Собрать всё (~3-4 часа)

- Сервисы берут настройки подключения из переменных окружения (не хардкод!)
- Перезапуск при падении, healthcheck для postgres в compose
- Сервис 2 при старте должен дождаться доступности своей БД (простой retry-цикл)
- Dockerfile для каждого сервиса + добавить их в `docker-compose.yml` (network, depends_on)
- Логи: пусть сервис 2 пишет в stdout, что забрал и что записал

## Этап 7. Полировка (~1-2 часа)

- Обработка ошибок: что если сервис 1 недоступен, запись не найдена?
- Краткий README: как поднять всё одной командой, как гонять ручки
- Подумай (не обязательно делай): как бы тут выглядела Kafka-версия из первоначального задания

---

## Порядок итого

0 → 1 → 2 → 3 → 4 → 5 → 6 → 7

Важно: этапы 3 и 4/5 можно менять местами, если хочется сначала собрать сервисы с БД, а gRPC прикрутить в конце. Но мини-демо gRPC (этап 3) делай обязательно до внедрения в сервисы — так проще дебажить.

## Проверочные вопросы себе после каждого этапа

- Docker: почему данные переживают `docker compose down`, но не переживают `down -v`?
- Compose: почему два postgres не могут оба слушать 5432 внутри сети, но могут на хосте?
- gRPC: где лежит контракт и почему его нельзя копировать в каждый сервис по отдельности?
- MSA: что изменится, если сервисов станет 5? Что уже в структуре этому мешает / помогает?
