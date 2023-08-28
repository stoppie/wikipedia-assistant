from fastapi import FastAPI, HTTPException, Depends, Query
import mysql.connector
from mysql.connector.connection import MySQLConnection
import sqlparse
from pydantic import BaseModel
import subprocess
import logging
import datetime
import os
from typing import List, Dict, Union

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration checks
PROJECT_ID = os.environ.get("PROJECT_ID")
SECRET_VERSION = os.environ.get("SECRET_VERSION")
DATABASE_HOSTNAME = os.environ.get("DATABASE_HOSTNAME")

# Checking for missing environment variables
missing_envs = [
    var
    for var, value in {
        "PROJECT_ID": PROJECT_ID,
        "SECRET_VERSION": SECRET_VERSION,
        "DATABASE_HOSTNAME": DATABASE_HOSTNAME,
    }.items()
    if not value
]

if missing_envs:
    raise EnvironmentError(f"Missing environment variables: {', '.join(missing_envs)}")


def set_private_ip() -> None:
    """
    Get the private IP from the gcloud command and set it as an environment variable.
    """
    try:
        result = (
            subprocess.check_output(
                [
                    "gcloud",
                    "sql",
                    "instances",
                    "describe",
                    DATABASE_HOSTNAME,
                    "--format=value(ipAddresses.ipAddress)",
                ],
                stderr=subprocess.STDOUT,
            )
            .decode("utf-8")
            .strip()
        )

    except subprocess.CalledProcessError as e:
        logger.error(f"Error executing command: {e}")
        raise HTTPException(
            status_code=500, detail="Failed to get database IP address."
        )

    os.environ["DATABASE_IP_ADDRESS"] = result


def get_database_connection() -> MySQLConnection:
    """
    Establish and return a connection to the database.

    Returns:
        A MySQL connection object.
    """
    if not os.environ.get("DATABASE_IP_ADDRESS"):
        set_private_ip()

    try:
        conn = mysql.connector.connect(
            user="api_user",
            password=os.environ.get("MYSQL_PWD"),
            host=os.environ.get("DATABASE_IP_ADDRESS"),
            database="wiki_assistant",
        )

        return conn

    except mysql.connector.Error as e:
        logger.error(f"Error connecting to database: {e}")
        raise HTTPException(status_code=500, detail="Database connection error.")


def process_result(
    result: Dict[str, Union[bytearray, datetime.datetime, str]]
) -> Dict[str, str]:
    """
    Process the result data, converting relevant fields.

    Args:
        result: A dictionary containing the row data.

    Returns:
        A processed dictionary with converted fields.
    """
    for key, value in result.items():
        if isinstance(value, bytearray):
            result[key] = value.decode("utf-8")
        elif isinstance(value, datetime.datetime):
            result[key] = value.isoformat()
    return result


wikiapp = FastAPI()


class SQLQuery(BaseModel):
    query: str


@wikiapp.post("/execute-sql")
async def execute_sql(
    query: SQLQuery,
    conn: MySQLConnection = Depends(get_database_connection),
) -> Dict[str, List[Dict[str, str]]]:
    """
    Execute a SQL query on the database and return the result.

    Args:
        query: A Pydantic model containing the SQL query.
        conn: A database connection object.

    Returns:
        A dictionary containing the results of the SQL query.
    """
    parsed = sqlparse.parse(query.query)

    if not parsed:
        raise HTTPException(status_code=400, detail="Invalid SQL query.")

    # Check if the query contains multiple SQL statements
    # or if any of the statements are not of the type 'SELECT' to prevent potential security risks.
    if len(parsed) > 1 or not all(stmt.get_type() == "SELECT" for stmt in parsed):
        raise HTTPException(status_code=400, detail="Only SELECT queries are allowed.")

    try:
        with conn.cursor(dictionary=True) as cursor:
            cursor.execute(query.query)
            results = cursor.fetchall()

        processed_results = [process_result(row) for row in results]

    except mysql.connector.Error as err:
        logger.error(f"Database error: {err}")
        raise HTTPException(status_code=500, detail="Database error.")

    finally:
        conn.close()

    return {"result": processed_results}


@wikiapp.get("/outdated-page")
async def get_outdated_page(
    category: str = Query(
        ..., description="The category to fetch the most outdated page for."
    ),
    conn: MySQLConnection = Depends(get_database_connection),
) -> Dict[str, Dict[str, str]]:
    """
    Return the most outdated page for a given category.

    Args:
        category: The category name.
        conn: A database connection object.

    Returns:
        A dictionary containing details of the most outdated page.
    """
    try:
        with conn.cursor(dictionary=True) as cursor:
            cursor.execute(
                "SELECT * FROM categoryoutdated WHERE category = %s",
                (category.encode("utf-8"),),
            )
            result = cursor.fetchone()

        if not result:
            raise HTTPException(
                status_code=404,
                detail=f"No outdated page found for category: {category}",
            )

        processed_result = process_result(result)

    except mysql.connector.Error as err:
        logger.error(f"Database error: {err}")
        raise HTTPException(status_code=500, detail="Database error.")

    finally:
        conn.close()

    return {"result": processed_result}
