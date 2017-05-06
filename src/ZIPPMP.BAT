tdstrip pmp.exe
touch file_id.diz
touch license.dsm
touch order.dsm
touch readme.dsm
touch dpmi16bi.ovl
touch rtm.exe
touch dsmi_ad.txt
touch pmp.rev
touch pmp.doc
touch pmp.exe
pkzip -a pmp%1 pmp.exe pmp.doc pmp.rev dsmi_ad.txt rtm.exe
pkzip -a pmp%1 dpmi16bi.ovl readme.dsm order.dsm license.dsm
pkzip -a pmp%1 file_id.diz
