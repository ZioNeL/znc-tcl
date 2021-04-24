
################
# znc-tcl v2.5 # - No vhosts are implemented on this script.
################

znc.tcl script v2.5 for Free-znc
To have this tcl working follow the following stepts:

 1. cd eggdrop_folder_name/scripts
 2. git clone https://github.com/ZioNeL/znc-tcl -b znc.tcl-no-vhosts
 3. cd znc.tcl
 4. edit znc.tcl to acomodate your network server znc settings
 5. edit eggdrop conf file to load znc.tcl file: source scripts/znc-tcl/znc.tcl
 6. .rehash your eggdrop from telnet or from irc using /msg eggdrop_name rehash <your_password>
 7. After you set our password on irc, request DCC chat with the bot: /ctcp eggdrop_name chat
 8. Grant you the znc.tcl admin flags : .chattr <your_username> +YQ 
 9. Activate lastseen module via DCC Partyline: .msg *status load_mod lastseen
10. Create lastseen user to the bot in order to not get ignored:

.+user lastseen

.+host lastseen *lastseen!znc@znc.in

.chattr lastseen +f

Now you are all set . 

!!! 
