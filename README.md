# Library App

A Ruby on Rails **JSON API** for a library. It manages:

- **Books**: the library's catalogue. Each book is one physical copy with a six-digit serial number.
- **Readers**: people registered with the library. Each has a six-digit library card number.
- **Borrow records**: which reader borrowed which book, when it is due and when it was returned.

The app also sends **return reminder emails** to readers: one 3 days before the due date and one
on the due date.

There is no frontend. The app only exposes an API.

## Contents

1. [Installation](#1-installation)
2. [Tech stack](#2-tech-stack)
3. [API endpoints](#3-api-endpoints)
4. [Things to fix or improve](#4-things-to-fix-or-improve)

---

## 1. Installation

Everything runs in Docker, so you don't need Ruby or PostgreSQL installed locally.

### Requirements

- [Docker](https://docs.docker.com/get-docker/) with Docker Compose (Docker Desktop includes both)
- Git

### Steps

```bash
git clone git@github.com:spoterala/libraryapp.git
cd libraryapp
bin/docker-menu
```

In the menu:

1. Choose **1) Run app**. The first run builds the Docker image, which takes a few minutes.
   The database is created and migrated automatically.
2. Choose **8) Load seed data** to add example books, readers and loans.
3. Open <http://localhost:3000/up>. A green page means the app is running.

The API is now available at `http://localhost:3000/api/v1/`.

### The `bin/docker-menu` script

`bin/docker-menu` is an interactive Bash menu for the common Docker tasks, so you don't have to
remember the `docker compose` commands. It can be run from any directory: it always switches to
the project root first. Before showing the menu it checks that Docker is running.

```
Library app — what do you want to do?
  1) Run app
  2) Run migrations
  3) Run tests
  4) Stop application
  5) Bundle install (after changing the Gemfile)
  6) Rails console
  7) Show app logs
  8) Load seed data (example books, readers, loans)
  9) Reset data (delete everything, then load seed data)
 10) Send return reminders now
  0) Exit
```

| Option | What it does | Command it runs |
|---|---|---|
| 1) Run app | Starts the database, the Rails server and the background job worker in the background, and waits until the app is healthy. Rebuilds the image if the Gemfile or Dockerfile changed. | `docker compose up --detach --build --wait` |
| 2) Run migrations | Runs pending database migrations. | `bin/rails db:migrate` |
| 3) Run tests | Runs the RSpec test suite (fails if test coverage is below 100%). | `bundle exec rspec` |
| 4) Stop application | Stops and removes all containers. Data in the database is kept. | `docker compose down` |
| 5) Bundle install | Updates `Gemfile.lock` after editing the `Gemfile`, rebuilds the image and restarts the app if it is running. | `bundle install`, then `docker compose build web` |
| 6) Rails console | Opens the Rails console, in the running app container or a temporary one. Type `exit` to go back to the menu. | `bin/rails console` |
| 7) Show app logs | Follows the logs of the Rails server and the job worker. Press Ctrl+C to go back to the menu. | `docker compose logs --follow --tail 100 web jobs` |
| 8) Load seed data | Adds 5 books, 5 readers and 9 borrow records from `db/seeds.rb`. Safe to run again: nothing is duplicated. | `bin/rails db:seed` |
| 9) Reset data | **Deletes all data** in the development database, then loads the seed data again. Asks for confirmation first. | `bin/rails db:seed:replant` |
| 10) Send return reminders now | Runs the reminder job immediately instead of waiting for 08:00. Emails are saved in `tmp/mails/`. | `bin/rails runner 'SendReturnRemindersJob.perform_now'` |
| 0) Exit | Closes the menu. The app keeps running. | — |

Other details:

- Each command is printed before it runs, followed by **Done.** or **Failed (exit code N)**.
- Ctrl+C stops the current action but keeps the menu open. Ctrl+D closes the menu.
- One-off commands (options 2, 3, 8, 9, 10) run in a temporary container that is removed afterwards.

### Without the menu

The same tasks with plain Docker Compose commands:

```bash
docker compose up                                        # start the app (Ctrl+C stops it)
docker compose up --build                                # same, after changing the Gemfile or Dockerfile
docker compose run --rm web bin/rails db:seed            # load seed data
docker compose run --rm web bundle exec rspec            # run tests
docker compose exec web bin/rails console                # Rails console (app must be running)
docker compose down                                      # stop the app
```

### Docker services

`docker compose up` starts three containers:

| Service | What it is |
|---|---|
| `db` | PostgreSQL 16. Data is stored in the `postgres_data` volume, so it survives restarts. |
| `web` | The Rails server on port 3000. Creates and migrates the database on start. |
| `jobs` | The Solid Queue worker that runs background jobs, e.g. the daily return reminders. Starts once `web` is healthy. |

### Emails

No real emails are sent. In development they are written to the log and saved as files in
`tmp/mails/<recipient email>`. Email previews: <http://localhost:3000/rails/mailers>.

Reminders are sent every day at **08:00 Europe/Warsaw time** (`config/recurring.yml`):

- **Due soon**: 3 days before the due date (sent late, with 2 or 1 days left, if that day was missed)
- **Due today**: on the due date

Each reminder is sent only once per loan.

---

## 2. Tech stack

| Part | Choice |
|---|---|
| Language | Ruby 4.0.9 |
| Framework | Rails 8.1.4, API-only mode |
| Database | PostgreSQL 16 |
| Web server | Puma |
| Background jobs | Solid Queue (stored in the main PostgreSQL database, no Redis needed) |
| Emails | Action Mailer (saved to files in development) |
| Tests | RSpec, FactoryBot |
| Test coverage | SimpleCov (100% line and branch coverage required) |
| Development environment | Docker, Docker Compose |
| Time zone | Europe/Warsaw |

---

## 3. API endpoints

All endpoints are under `/api/v1/`. Requests and responses are JSON.

- Books are identified by their **serial number** (six digits, e.g. `000001`).
- Readers are identified by their **library card number** (six digits, e.g. `100001`).
- Database ids are never shown.
- Send `Content-Type: application/json` with every request that has a body.

### Summary

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/v1/books` | [List books](#list-books) |
| `GET` | `/api/v1/books/:serial_number` | [Show a book with its borrowing history](#show-a-book) |
| `POST` | `/api/v1/books` | [Add a book](#add-a-book) |
| `DELETE` | `/api/v1/books/:serial_number` | [Delete a book](#delete-a-book) |
| `POST` | `/api/v1/books/:serial_number/borrow` | [Borrow a book](#borrow-a-book) |
| `POST` | `/api/v1/books/:serial_number/return` | [Return a book](#return-a-book) |
| `GET` | `/api/v1/readers` | [List readers](#list-readers) |
| `GET` | `/api/v1/readers/:library_card_number` | [Show a reader with their borrowing history](#show-a-reader) |
| `POST` | `/api/v1/readers` | [Add a reader](#add-a-reader) |
| `DELETE` | `/api/v1/readers/:library_card_number` | [Delete a reader](#delete-a-reader) |

### Errors

| Status | When | Body |
|---|---|---|
| `400 Bad Request` | The required top-level key (`book` / `reader`) is missing | `{"error": "param is missing or the value is empty or invalid: book"}` |
| `404 Not Found` | No book / reader with that number | `{"error": "Book not found"}` |
| `409 Conflict` | The action isn't allowed in the current state (e.g. the book is already borrowed) | `{"error": "Book is already borrowed"}` |
| `422 Unprocessable Content` | Validation failed | `{"errors": {"serial_number": ["has already been taken"]}}` |

---

### Books

#### List books

`GET /api/v1/books`

Returns all books, ordered by serial number.

**Input:** none

**Output:** `200 OK`

| Field | Description |
|---|---|
| `serial_number` | Six digits |
| `title` | Title |
| `author` | Author |
| `status` | `"available"` or `"borrowed"` |
| `due_date` | When the book must be returned, or `null` if it is available |

```bash
curl http://localhost:3000/api/v1/books
```

```json
[
  {
    "serial_number": "000001",
    "title": "Pride and Prejudice",
    "author": "Jane Austen",
    "status": "borrowed",
    "due_date": "2026-11-20"
  },
  {
    "serial_number": "000002",
    "title": "Emma",
    "author": "Jane Austen",
    "status": "available",
    "due_date": null
  }
]
```

#### Show a book

`GET /api/v1/books/:serial_number`

Returns one book with its full borrowing history, newest loan first.

**Input:** serial number in the URL

**Output:** `200 OK`. The same fields as in the list, plus `borrow_records`. Each record has
`borrowed_date`, `due_date`, `return_date` (`null` if not returned yet) and `reader`.

**Errors:** `404` book not found

```bash
curl http://localhost:3000/api/v1/books/000002
```

```json
{
  "serial_number": "000002",
  "title": "Emma",
  "author": "Jane Austen",
  "status": "available",
  "due_date": null,
  "borrow_records": [
    {
      "borrowed_date": "2026-08-03",
      "due_date": "2026-09-02",
      "return_date": "2026-08-20",
      "reader": {
        "library_card_number": "100002",
        "full_name": "Charlotte Lucas",
        "email": "charlotte.lucas@example.com"
      }
    }
  ]
}
```

#### Add a book

`POST /api/v1/books`

**Input:**

| Field | Required | Rules |
|---|---|---|
| `book.serial_number` | yes | Exactly six digits, unique |
| `book.title` | yes | |
| `book.author` | yes | |

**Output:** `201 Created`, the new book (same fields as in the list)

**Errors:** `400` no `book` key, `422` validation failed

```bash
curl -X POST http://localhost:3000/api/v1/books \
     -H 'Content-Type: application/json' \
     -d '{"book": {"serial_number": "000123", "title": "Solaris", "author": "Stanisław Lem"}}'
```

```json
{
  "serial_number": "000123",
  "title": "Solaris",
  "author": "Stanisław Lem",
  "status": "available",
  "due_date": null
}
```

Validation error (`422`):

```json
{
  "errors": {
    "serial_number": ["must be exactly six digits"],
    "title": ["can't be blank"]
  }
}
```

#### Delete a book

`DELETE /api/v1/books/:serial_number`

Deletes the book together with its borrowing history. A book that is currently borrowed can't be deleted.

**Input:** serial number in the URL

**Output:** `204 No Content`, empty body

**Errors:** `404` book not found, `409` book is currently borrowed

```bash
curl -X DELETE http://localhost:3000/api/v1/books/000123
```

Error (`409`):

```json
{ "error": "Cannot delete a book that is currently borrowed" }
```

#### Borrow a book

`POST /api/v1/books/:serial_number/borrow`

Lends the book to a reader. The borrowed date is today and the due date is today + 30 days.
Neither can be set by the client.

**Input:**

| Field | Required | Rules |
|---|---|---|
| `reader_card_number` | yes | Library card number of an existing reader |

**Output:** `201 Created`, the borrow record

| Field | Description |
|---|---|
| `book_serial_number` | The borrowed book |
| `reader_card_number` | The reader |
| `borrowed_date` | Today |
| `due_date` | Today + 30 days |
| `return_date` | `null` |

**Errors:** `404` book not found, `422` no reader with that card number, `409` book is already borrowed

```bash
curl -X POST http://localhost:3000/api/v1/books/000002/borrow \
     -H 'Content-Type: application/json' \
     -d '{"reader_card_number": "100001"}'
```

```json
{
  "book_serial_number": "000002",
  "reader_card_number": "100001",
  "borrowed_date": "2026-11-04",
  "due_date": "2026-12-04",
  "return_date": null
}
```

Unknown reader (`422`):

```json
{ "errors": { "reader_card_number": ["doesn't match any reader"] } }
```

#### Return a book

`POST /api/v1/books/:serial_number/return`

Marks the current loan of the book as returned today.

**Input:** serial number in the URL, no body

**Output:** `200 OK`, the borrow record (same fields as for borrowing) with `return_date` set

**Errors:** `404` book not found, `409` book is not borrowed

```bash
curl -X POST http://localhost:3000/api/v1/books/000002/return
```

```json
{
  "book_serial_number": "000002",
  "reader_card_number": "100001",
  "borrowed_date": "2026-11-04",
  "due_date": "2026-12-04",
  "return_date": "2026-11-04"
}
```

---

### Readers

#### List readers

`GET /api/v1/readers`

Returns all readers, ordered by library card number.

**Input:** none

**Output:** `200 OK`

| Field | Description |
|---|---|
| `library_card_number` | Six digits |
| `full_name` | Full name |
| `email` | Email address (lowercase) |
| `borrowed_books_count` | Number of books the reader has right now (not returned yet) |

```bash
curl http://localhost:3000/api/v1/readers
```

```json
[
  {
    "library_card_number": "100001",
    "full_name": "Elizabeth Bennet",
    "email": "elizabeth.bennet@example.com",
    "borrowed_books_count": 0
  },
  {
    "library_card_number": "100005",
    "full_name": "John Thornton",
    "email": "john.thornton@example.com",
    "borrowed_books_count": 1
  }
]
```

#### Show a reader

`GET /api/v1/readers/:library_card_number`

Returns one reader with their full borrowing history, newest loan first.

**Input:** library card number in the URL

**Output:** `200 OK`. `library_card_number`, `full_name`, `email` and `borrow_records`. Each record
has `borrowed_date`, `due_date`, `return_date` (`null` if not returned yet) and `book`.

**Errors:** `404` reader not found

```bash
curl http://localhost:3000/api/v1/readers/100002
```

```json
{
  "library_card_number": "100002",
  "full_name": "Charlotte Lucas",
  "email": "charlotte.lucas@example.com",
  "borrow_records": [
    {
      "borrowed_date": "2026-08-03",
      "due_date": "2026-09-02",
      "return_date": "2026-08-20",
      "book": {
        "serial_number": "000002",
        "title": "Emma",
        "author": "Jane Austen"
      }
    }
  ]
}
```

#### Add a reader

`POST /api/v1/readers`

**Input:**

| Field | Required | Rules |
|---|---|---|
| `reader.library_card_number` | yes | Exactly six digits, unique |
| `reader.full_name` | yes | |
| `reader.email` | yes | Valid email address, unique (case doesn't matter; stored in lowercase) |

**Output:** `201 Created`, the new reader (`library_card_number`, `full_name`, `email`)

**Errors:** `400` no `reader` key, `422` validation failed

```bash
curl -X POST http://localhost:3000/api/v1/readers \
     -H 'Content-Type: application/json' \
     -d '{"reader": {"library_card_number": "100006", "full_name": "Margaret Hale", "email": "margaret.hale@example.com"}}'
```

```json
{
  "library_card_number": "100006",
  "full_name": "Margaret Hale",
  "email": "margaret.hale@example.com"
}
```

Validation error (`422`):

```json
{ "errors": { "email": ["is not a valid email address"] } }
```

#### Delete a reader

`DELETE /api/v1/readers/:library_card_number`

Readers with any borrow records (even returned ones) can't be deleted, so the borrowing history is kept.

**Input:** library card number in the URL

**Output:** `204 No Content`, empty body

**Errors:** `404` reader not found, `409` reader has borrow records

```bash
curl -X DELETE http://localhost:3000/api/v1/readers/100006
```

Error (`409`):

```json
{ "error": "Cannot delete a reader who has borrow records" }
```

---

## 4. Things to fix or improve

- [ ] **Updating books and readers.** There are no `PATCH` endpoints yet, so a typo in a title or
  a reader's new email address can't be corrected through the API.
- [ ] **Overdue reminders.** Only "due soon" and "due today" emails exist. Nothing is sent after the
  due date has passed. Needs a decision on how often to send them (once, daily, weekly).
- [ ] **Authentication.** The API is open: anyone who can reach it can add, delete, borrow and
  return books, and see readers' email addresses.
- [ ] **Limit of borrowed books per reader.** A reader can currently borrow any number of books at once.
- [ ] **Pagination for the list of books.** `GET /api/v1/books` returns every book in one response,
  which will get slow as the catalogue grows.
- [ ] **Separate authors table.** The author is a text field on each book. Authors should be their own
  table, with books linked to them, so the same author isn't typed (and possibly misspelled) many times.
- [ ] **Searching books and readers.** There is no way to search, e.g. books by title or author,
  or readers by name or email.
