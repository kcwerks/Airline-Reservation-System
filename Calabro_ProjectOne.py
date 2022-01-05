## Kyle Calabro
## Dr. Dutta
## CMPS 664 - Project One
## 28 April 2021

import mysql.connector
import pandas as pd
import xml.dom.minidom
import lxml
from lxml import etree

flattened_data = []
headers = []

def get_text(nodelist):
    node_data = []
    for node in nodelist:
        if node.nodeType == node.TEXT_NODE:
            node_data.append(node.data)

    return "".join(node_data)

def compile_data_point(dataPoint):
    return get_text(dataPoint.childNodes)

def compile_data(data, row_count):
    data_row = []

    for dataPoint in data:
        data_row.append(compile_data_point(dataPoint))

    if row_count == 0:
        headers[:] = list(data_row)

    else:
        flattened_data.append(data_row)

def compile_row(row, row_count):
    compile_data(row.getElementsByTagName("Data"), row_count)

def compile_rows(rows):
    row_count = 0

    for row in rows:
        compile_row(row, row_count)
        row_count += 1

# Parse the file, taking in all the rows that are tagged "Row"
input_file = xml.dom.minidom.parse("./PNR.xml")
rows = input_file.getElementsByTagName("Row")

# Compile the rows so that we get the actual data
compile_rows(rows)

PNR_df = pd.DataFrame(flattened_data, columns = headers)

# Drop any rows with missing information
PNR_df = PNR_df.dropna()

# Read in information from the iata.txt file which contains the identifiers for various airports
airport_file = open("iata.txt", "r", encoding = "utf8").read()
airports = airport_file.split('\n')

# Connect to the DB
reservations_db = mysql.connector.connect(host = "localhost", user = "root", passwd = "kyle1727", database = "project_one")
db_cursor = reservations_db.cursor()

# Insert all the original data into the primary tables
# row[8] -> row.class
for row in PNR_df.itertuples():
    db_cursor.execute("INSERT INTO project_one.Pnr(first_name, last_name, address, age, origin, destination, travel_date, class, booking_time, num_passengers)" +
            "VALUES(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)", (row.firstname, row.lastname, row.address, row.age, row.source, row.dest, row.travelDate, row[8], row.bookingTime, row.npass))

for item in airports:
    db_cursor.execute("INSERT INTO project_one.Airports(iata_code) VALUES(%s)", (item,))

reservations_db.commit()

# Insert the appropriate data to the tables derived from the original data
db_cursor.execute("CALL run_setup_inserts()")
reservations_db.commit()

# Reserve seats, populating the Master_reservations table 
# which also updates the flights table accordingly
db_cursor.execute("CALL reserve_seats()")
reservations_db.commit()

db_cursor.close()
