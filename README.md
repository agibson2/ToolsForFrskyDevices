# ToolsForFrskyDevices
Script and tools to use with FrSky devices

The first tool is a powershell script to convert FrSky logfiles to .gpx file format for use in sites like https://ayvri.com.

## FrSkyLog2Gpx.ps1
It has an option to use the vario height for height data instead of using GPS height data.  GPS height data is inherently less accurate than vaio data.

You can use it like this...

Frsky2Gpx.ps1 -UseVarioHeight -Filename "C:\Users\Someuser\Documents\Arctus-2022-01-21-13-40-00.csv

- -Filename is the input FrSky logfile
- -UseVarioHeight tells the script not to use the GPS height data and to use the vario height data instead.
- -ForceUTC Parse the logfile as UTC instead of localtime to force ayvri.com to show local time.  The time is incorrect but it forces ayvri to show local time.  Only use this option for ayvri.com site if you want the time shown as local time instead of UTC.

The output .gpx file will be placed in the same directory as the source file.

You can use the -Debug option to get more verbose output.

This script doesn't do any kind of filtering on the actual data.  On first aquisition of GPS, the accuracy can be rather low because it doesn't have as many satelites yet.  You might see it show GPS data somewhere else until it gets a better lock on more satellites.  I currently manually remove that initial data from the logfiles before converting it.  I might look into some kind of analysis of the data to remove any data way outside of the area of the majority of the data.  I haven't decided to tackle that yet.  The script currently just parses one line at a time without any future or past point data analysis.
