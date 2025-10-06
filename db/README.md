# Database Folder

This folder contains database-related files for the Plant Health AI project.

## Files

- `init.sql` - Database initialization script with table creation
- `queries.sql` - Common MySQL queries for development and testing
- `.gitkeep` - Keeps this folder in git

## Usage

### Initialize Database
```bash
mysql -u root -p < init.sql
```

### Run Queries
```bash
mysql -u root -p plantdb < queries.sql
```

### Connect to Database
```bash
mysql -u root -p plantdb
```

## Database Schema

The database contains two main tables:

1. **plant_analyses** - Stores analysis results
2. **plant_images** - Stores image metadata linked to analyses

## Environment Variables

Make sure to set these environment variables in your `.env` file:

```
DB_URL=mysql+pymysql://root:password@localhost:3306/plantdb
```

## Docker

The database is configured to run in Docker via `docker-compose.dev.yml`:

```yaml
db:
  image: mysql:8
  environment:
    MYSQL_ROOT_PASSWORD: password
    MYSQL_DATABASE: plantdb
  ports: ["3306:3306"]
```
