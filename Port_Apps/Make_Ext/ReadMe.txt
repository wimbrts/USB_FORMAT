
Make_Ext.exe
============

Make_Ext.exe is a 32-bit Windows executable.

If running Windows 7, you may need to use right-click 'Run as Administrator'

It will create a file which is internally formatted with a linux ext filesystem.

The ext file can be used by linux for persistent storage.

The volume name for most Ubuntu-based linux distributions is casper-rw (but not always).

Look for a .mnu file in \_ISO\docs\Sample Mnu Files\Linux for a menu that includes persistence.

The File Name can be anything you like (avoid spaces in the name).
The Volume Name must be casper-rw for most Ubuntu ISOs.
I suggest using ext3 or ext4 because ext2 persistence files can get easily corruputed!

Always shut down linux 'nicely' to avoid file corruption - do not just switch off the system or pull out the USB drive.




.isopersist file extension
==========================

If your ISO is Ubuntu-based, you do not need a .mnu file, just use the file extension of .isopersist instead of .iso.

e.g.

\_ISO\LINUX\Ubuntu64.isopersist
\_ISO\LINUX\Ubuntu64-rw

OR

\_ISO\LINUX\Ubuntu64.isopersist
\Ubuntu64-rw


The filename must be the same as the ISO file but with -rw on the end  (e.g. fred.isopersist and fred-rw).

