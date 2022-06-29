# RefinedSilo
Silo but with automatic crafting and processing
~~~
Usage: ui                  -- view all items in storage
~~~

#### Install:
1) place computer or advanced computer
3) place minecraft chests
4) connect computer to chests by using wired modems and networking cables
5) right click the modems to connect the computer/chests to network
6) enter the following in the computer
~~~
wget run https://raw.githubusercontent.com/GuitarMusashi616/RefinedSilo/master/startup.lua
~~~
7) choose a dump chest and pickup chest, edit DUMP_CHEST_NAME and PICKUP_CHEST_NAME in the silo.lua file so that they have the correct chest name at the right of their respective equals sign (chest name is displayed when right clicking modem next to the chest) (run "edit silo" to edit file)
8) all done, now the above commands should work

### Adding Catalysts (Furnace, Pulverizer, Pressure Chamber, etc.)
1) make a directory named "patterns"
2) place a barrel where you want the items to be imported
3) add the barrel to the network
4) make a new file in patterns based on the network name of the barrel (shown in chat when connected to network) ie barrel_4.lua
5) have each file return a table with this format {["minecraft:item_name"] = {5, ingredient_name, 2, other_ingredient}} ie https://github.com/GuitarMusashi616/patterns
6) send the output of the catalyst directly to the dump chest

#### Required Mods:
cc-tweaked-1.16.5-1.98.1.jar
