#!/bin/bash

# Startet einen lokalen HTTP Fileserver, dann kann via curl das File geholt werden,
# aus der Konsole der VM: curl -LO http://192.168.2.103:10080/...

httpserv -p 10080
