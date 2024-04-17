# IshiaDB

## About

Database for files. To store, optimise, dublicate and archive files by namespaces, databases and tables

## Usage

To start use `ishia`, use `-p 4200` to specify the port. It will create directory to store database's state or scan for existing one

### PATCH

Send file with queries
Must be send to http://localhost:port/namespace/database

PATCH http://localhost:4200/MyNameSpace/MyDataBase

MyNameSpace d namespace;
MyDataBase d database;
MyImageTable d table;
MyImageTable m { l:31:6 };

### POST

For files upload
Must be send to http://localhost:port/namespace/database/table

POST http://localhost:4200/MyNameSpace/MyDataBase/MyImageTable

### GET

To get file by hash and mark
Must be send to http://localhost:port/namespace/database/table/hash-mark

GET http://localhost:4200/MyNameSpace/MyDataBase/MyImageTable/3540784060-l

### EXAMPLES

Check for advance query [example](./example/example.ih)