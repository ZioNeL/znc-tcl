
################
# znc-tcl v3.0 #
################

znc.tcl script v3.0 for Free-znc
To have this tcl working follow the following stepts:

 1. cd eggdrop_folder_name/scripts
 2. git clone https://github.com/ZioNeL/znc-tcl
 3. cd znc.tcl
 4. edit znc.tcl to acomodate your network server znc settings
 5. edit eggdrop conf file to load znc.tcl file: source scripts/znc-tcl/znc.tcl
 6. .rehash your eggdrop from telnet or from irc using /msg eggdrop_name rehash <your_password>
 7. After you set your password on irc, request DCC chat with the bot: /ctcp eggdrop_name chat
 8. Grant znc admin flags to your account : 
  
 .chattr <your_username> +YQ 
 
 9. Activate znc script in your channel and lastseen with controlpanel znc modules via DCC Partyline: 
 
 .chanset #your_free_znc_channel +znc
 
 .msg *status loadmod lastseen
 
 .msg *status loadmod controlpanel
 
10. Create lastseen user to the bot in order to not get ignored:

 .+user lastseen

 .+host lastseen *lastseen!znc@znc.in

 .+host lastseen *controlpanel!znc@znc.in

 .chattr lastseen +f
 
 .save

 Now you are all set . 

 This README file was last updated by ZioN on 06.05.2021 !!!! 
