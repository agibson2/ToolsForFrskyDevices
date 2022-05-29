# ToolsForFrskyDevices
Script and tools to use with FrSky devices

The first tool is a powershell script to convert FrSky logfiles to .gpx file format for use in sites like https://ayvri.com.
FrSkyLog2Gpx.ps1

It has an option to use the vario height for height data instead of using GPS height data.  GPS height data is inherently less accurate than vaio data.

You can use it like this...

Frsky2Gpx.ps1 -UseVarioHeight -Filename "C:\Users\Someuser\Documents\Arctus-2022-01-21-13-40-00.csv

-Filename is the input FrSky logfile
-UseVarioHeight tells the script not to use the GPS height data and to use the vario height data instead.

The output .gpx file will be placed in the same directory as the source file.
