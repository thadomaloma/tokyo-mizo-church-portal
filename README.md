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
SEED_ADMIN_PASSWORD=Admin@2026 \
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

Local admin login:

| Email | Password |
| --- | --- |
| admin@tokyomizochurch.org | Admin@2026 |

## Purpose

The portal is designed to improve church administration, record keeping, communication, and financial transparency while providing a secure and user-friendly experience for church leaders and members.

Developed for Tokyo Mizo Church, Japan.
