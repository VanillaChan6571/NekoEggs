# MariaDB

## From their [Website](https://mariadb.org/)

One of the most popular database servers. Made by the original developers of MySQL.
Guaranteed to stay open source.

## Minimum RAM warning

There is no actual minimum suggested for MariaDB.

See here <https://mariadb.com/kb/en/library/mariadb-hardware-requirements/>

## Server Ports

Ports required to run the server in a table format.

| Port    | default |
|---------|---------|
| Server  |  3306   |

Please note you can change the port or supply a different port. You are not locked at 3306.

## Notes + Usage

MariaDB 11.4 seems to run differently than 10, we use the "--skip-grant-tables" to make the server run. There could be different ways but this is the way I know. Please suggest a better startup so MariaDB runs without having to use `FLUSH PRIVILEGES;` when trying to do root things at the beginning.

When first in console. We recommend running `FLUSH PRIVILEGES;` to do things like create user otherwise you may get `ERROR 1290 (HY000): The MariaDB server is running with the --skip-grant-tables option so it cannot execute this statement` when doing things.
