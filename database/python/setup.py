import mysql.connector
from mysql.connector import cursor
import sys
import argparse
import logging
from argparse import Namespace

logging.basicConfig(level=logging.INFO)


def create_database(cursor: cursor.MySQLCursor, db_name: str) -> None:
    """
    Creates a new database with the specified name if it doesn't exist.

    Args:
        cursor: The MySQL cursor to execute the query.
        db_name: Name of the database to create.
    """
    cursor.execute(f"CREATE DATABASE IF NOT EXISTS {db_name};")


def create_user(cursor: cursor.MySQLCursor, username: str, password: str) -> None:
    """
    Creates a new user with the specified username and password if it doesn't exist.

    Args:
        cursor: The MySQL cursor to execute the query.
        username: Name of the user to create.
        password: Password for the user.
    """
    cursor.execute(
        "CREATE USER IF NOT EXISTS %s@'%' IDENTIFIED BY %s;", (username, password)
    )


def grant_privileges(
    cursor: cursor.MySQLCursor, privileges: str, db_name: str, username: str
) -> None:
    """
    Grants specified privileges on a database to a user.

    Args:
        cursor: The MySQL cursor to execute the query.
        privileges: The privileges to grant.
        db_name: Name of the database.
        username: Name of the user to grant privileges to.
    """
    query = f"GRANT {privileges} ON {db_name}.* TO %s@'%';"
    cursor.execute(query, (username,))


def setup_database(args: Namespace) -> None:
    """
    Sets up the database:
    1. Creates the databases (production and staging).
    2. Creates the users (dev and api).
    3. Grants privileges to the users.
    4. Flushes the privileges.

    Args:
        args: Command line arguments containing database and user details.
    """
    try:
        conn = mysql.connector.connect(
            host=args.host, user=args.root_user, password=args.root_password
        )

        cursor = conn.cursor()

        # 1. Create the databases
        for db_name in [args.database_prod_name, args.database_staging_name]:
            create_database(cursor, db_name)

        # 2. Create the users
        create_user(cursor, args.database_dev_user, args.database_dev_user_pwd)
        create_user(cursor, args.database_api_user, args.database_api_user_pwd)

        # 3. Grant privileges to the users for the databases
        grant_privileges(
            cursor,
            "SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, REFERENCES",
            args.database_prod_name,
            args.database_dev_user,
        )
        grant_privileges(
            cursor,
            "SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, REFERENCES",
            args.database_staging_name,
            args.database_dev_user,
        )
        grant_privileges(
            cursor, "SELECT", args.database_prod_name, args.database_api_user
        )

        # 4. Flush privileges
        cursor.execute("FLUSH PRIVILEGES;")

        cursor.close()
        conn.close()

        logging.info("Database setup completed!")

    except mysql.connector.Error as err:
        logging.error(f"MySQL Error: {err}")
        sys.exit(1)

    except Exception as e:
        logging.error(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Setup MySQL databases and users.")
    parser.add_argument("host", type=str, help="Database host.")
    parser.add_argument("root_password", type=str, help="Root password.")
    parser.add_argument("database_prod_name", type=str, help="Production DB name.")
    parser.add_argument("database_staging_name", type=str, help="Staging DB name.")
    parser.add_argument("database_dev_user", type=str, help="Dev user name.")
    parser.add_argument("database_dev_user_pwd", type=str, help="Dev user password.")
    parser.add_argument("database_api_user", type=str, help="API user name.")
    parser.add_argument("database_api_user_pwd", type=str, help="API user password.")

    args = parser.parse_args()

    args.root_user = "root"

    setup_database(args)
