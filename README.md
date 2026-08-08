# Tokyo Mizo Church Portal

Tokyo Mizo Church Portal is a modern church management system built with Ruby on Rails 8. It helps church leaders manage members, finances, meeting minutes, announcements, events, and notifications from a single platform.

![Tokyo Mizo Church Portal dashboard preview](docs/dashboard-preview.png)

## Features

* Member Management
* Finance Management (Income, Expenses, Reports)
* Meeting Minutes & Resolution Tracking
* Church Announcements
* Event Management
* Notifications System
* Role-Based Access Control
* PDF & Excel Report Export
* Mobile-Friendly Responsive Design

## User Roles

* Super Admin
* Pastor
* Adviser
* Secretary
* Treasurer
* Member

## Technology Stack

* Ruby on Rails 8
* PostgreSQL
* Hotwire (Turbo & Stimulus)
* Tailwind CSS
* Devise Authentication
* Prawn PDF
* Axlsx Excel Export

## Local Setup

Clone the repository:

```bash
git clone git@github.com:thadomaloma/tokyo-mizo-church-portal.git
cd tokyo-mizo-church-portal
```

Install dependencies:

```bash
bundle install
```

Create and prepare the database:

```bash
bin/rails db:prepare
```

Create the first admin account:

```bash
SEED_ADMIN_EMAIL=admin@tokyomizochurch.org \
SEED_ADMIN_PASSWORD='<use-a-long-unique-password>' \
SEED_ADMIN_NAME="Super Admin" \
bin/rails db:seed
```

Start the app:

```bash
bin/dev
```

Open:

```text
http://localhost:3000
```

The seed password is applied only when the account is first created. To rotate it
intentionally, set `RESET_SEED_ADMIN_PASSWORD=true` for one seed run and then
remove that variable.

## Railway Production Setup

The checked-in `railway.json` uses the Dockerfile, runs `db:prepare` before a
deployment, and checks `/up` before sending traffic to a new instance.

Required Railway variables:

* `DATABASE_URL` (normally supplied by the attached Railway PostgreSQL service)
* `SECRET_KEY_BASE` or `RAILS_MASTER_KEY`
* `GMAIL_USERNAME`, `GMAIL_APP_PASSWORD`, and optionally `MAILER_FROM`
* `SOLID_QUEUE_IN_PUMA=true` when jobs should run in the web service

`APP_HOST` is optional; the app uses `RAILWAY_PUBLIC_DOMAIN` automatically.

Meeting PDFs and signature images must not be kept on Railway's ephemeral
container filesystem. Attach a Railway volume to the web service, mount it at a
dedicated path such as `/rails/storage`, and let Railway provide
`RAILWAY_VOLUME_MOUNT_PATH`. If the container cannot write to a new volume,
configure Railway's documented `RAILWAY_RUN_UID=0` volume permission setting.
Back up the volume separately; a database backup does not include uploads.

Do not keep `SEED_ADMIN_PASSWORD` in Railway after the first successful seed.
Leaving it configured is unnecessary, even though normal deploys no longer reset
the existing password.

## Purpose

The portal is designed to improve church administration, record keeping, communication, and financial transparency while providing a secure and user-friendly experience for church leaders and members.

Developed for Tokyo Mizo Church, Japan.
